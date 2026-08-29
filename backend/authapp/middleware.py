import time

from django.core.cache import cache
from django.http import HttpResponse, JsonResponse
from django.shortcuts import redirect


class MaintenanceModeMiddleware:
    """
    Returns 503 for all /api/ requests when SiteConfig.maintenance_mode is True.
    Admin paths are always allowed so admins can turn it back off.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith('/api/') and not request.path.startswith('/admin/'):
            try:
                # Cache the flag 30s — avoid a SiteConfig query on every API hit.
                on = cache.get('maintenance_mode')
                if on is None:
                    from authapp.models import SiteConfig
                    cfg = SiteConfig.objects.filter(pk=1).first()
                    on = bool(cfg and cfg.maintenance_mode)
                    cache.set('maintenance_mode', on, 30)
                if on:
                    return JsonResponse(
                        {'detail': 'The system is under maintenance. Please try again later.'},
                        status=503,
                    )
            except Exception:
                pass  # DB not ready — let the request through
        return self.get_response(request)


class AdminInactivityMiddleware:
    """
    Auto-logs out admin users after 30 minutes of inactivity.
    Only applies to /admin/ paths; updates session timestamp on each request.
    """
    INACTIVITY_TIMEOUT = 1800  # 30 minutes

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if not request.path.startswith('/admin/'):
            return self.get_response(request)

        # Skip login and logout pages
        if request.path in ('/admin/login/', '/admin/logout/'):
            return self.get_response(request)

        now = int(time.time())
        last = request.session.get('last_admin_activity')

        if last is not None and (now - last) > self.INACTIVITY_TIMEOUT:
            request.session.flush()
            return redirect('/admin/login/')

        # Only write the session (a DB write) once per minute, not every
        # request. Timeout resolution stays well under the 30-min window.
        if last is None or (now - last) > 60:
            request.session['last_admin_activity'] = now
        return self.get_response(request)


class IdempotencyMiddleware:
    """Makes a retried write safe to send twice.

    Applies only to unsafe /api/ methods carrying an `Idempotency-Key` header —
    the offline queue sets one per queued item. The first request through
    claims the key and stores its response; a replay gets that response back
    instead of creating a second sale, payment, or stock movement.

    Anything that did not complete successfully releases the key, so a genuine
    retry after a validation or server error still reaches the view.
    """
    TTL_SECONDS = 24 * 60 * 60
    UNSAFE = {'POST', 'PUT', 'PATCH', 'DELETE'}

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        key = (request.headers.get('Idempotency-Key') or '')[:64]
        if (not key or request.method not in self.UNSAFE
                or not request.path.startswith('/api/')):
            return self.get_response(request)

        import hashlib
        from datetime import timedelta
        from django.utils import timezone
        from authapp.models import IdempotencyRecord

        auth = request.headers.get('Authorization', '')
        token_hash = hashlib.sha256(auth.encode()).hexdigest()[:64]
        try:
            cutoff = timezone.now() - timedelta(seconds=self.TTL_SECONDS)
            IdempotencyRecord.objects.filter(
                key=key, token_hash=token_hash, created_at__lt=cutoff).delete()
            record, created = IdempotencyRecord.objects.get_or_create(
                key=key, token_hash=token_hash)
        except Exception:
            # Table missing (migration not applied yet) or DB hiccup — never
            # block a write over the replay guard.
            return self.get_response(request)

        if not created:
            if record.status_code == 0:
                return JsonResponse(
                    {'detail': 'This request is already being processed.'},
                    status=409)
            return HttpResponse(record.body, status=record.status_code,
                                content_type='application/json')

        try:
            response = self.get_response(request)
        except Exception:
            record.delete()  # nothing was recorded — let the client retry
            raise

        applied = (200 <= response.status_code < 300
                   and not getattr(response, 'streaming', False))
        if applied:
            record.status_code = response.status_code
            record.body = response.content.decode('utf-8', 'replace')
            record.save(update_fields=['status_code', 'body'])
        else:
            record.delete()
        return response
