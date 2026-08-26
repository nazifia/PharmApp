import random
import time
from datetime import timedelta

from django.core.cache import cache
from django.http import HttpResponse, JsonResponse
from django.shortcuts import redirect
from django.utils import timezone


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
    """
    Makes replayed writes safe.

    A request that carries an ``Idempotency-Key`` header is executed at most
    once. The first request claims the key, runs the view, and stores the
    response; any later request with the same key gets that stored response
    back without touching the database again.

    Only unsafe methods on /api/ paths are covered — a GET has nothing to
    duplicate. Server errors (5xx) release the key so the client can retry for
    real, and a key whose original request is still in flight gets 409 rather
    than being allowed to run in parallel.
    """
    SAFE_METHODS = {'GET', 'HEAD', 'OPTIONS', 'TRACE'}
    # Responses larger than this are passed through unstored: replaying one
    # would cost more than re-running the (already deduplicated) view.
    MAX_STORED_BODY = 256 * 1024

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        key = request.headers.get('Idempotency-Key', '')
        if (not key
                or request.method in self.SAFE_METHODS
                or not request.path.startswith('/api/')):
            return self.get_response(request)

        # Imported here so the middleware module stays importable before apps load.
        from django.db import IntegrityError, transaction
        from .models import IdempotencyRecord

        try:
            # Nested atomic so the duplicate-key IntegrityError rolls back only
            # this INSERT and leaves any surrounding transaction usable.
            with transaction.atomic():
                record = IdempotencyRecord.objects.create(
                    key=key[:255], method=request.method, path=request.path[:500],
                )
        except IntegrityError:
            return self._replay(key)

        try:
            response = self.get_response(request)
        except Exception:
            # View blew up — release the key so a retry can actually run.
            record.delete()
            raise

        if response.status_code >= 500:
            record.delete()
            return response

        body = b'' if getattr(response, 'streaming', False) else response.content
        if len(body) > self.MAX_STORED_BODY or getattr(response, 'streaming', False):
            record.delete()
            return response

        record.status_code = response.status_code
        record.response_body = body.decode('utf-8', errors='replace')
        record.content_type = response.get('Content-Type', 'application/json')[:100]
        record.save(update_fields=['status_code', 'response_body', 'content_type'])
        self._purge_expired()
        return response

    def _replay(self, key):
        from .models import IdempotencyRecord

        record = IdempotencyRecord.objects.filter(key=key[:255]).first()
        if record is None:
            # Raced with a purge or a rollback — let the caller try again.
            return JsonResponse(
                {'detail': 'Request is being processed — please retry.'}, status=409)
        if record.status_code is None:
            return JsonResponse(
                {'detail': 'Request is being processed — please retry.'}, status=409)
        response = HttpResponse(
            record.response_body,
            status=record.status_code,
            content_type=record.content_type or 'application/json',
        )
        response['Idempotency-Replayed'] = 'true'
        return response

    def _purge_expired(self):
        """Drop expired keys occasionally rather than on a schedule."""
        if random.random() > 0.01:  # ~1 request in 100 pays for the cleanup
            return
        from .models import IdempotencyRecord

        cutoff = timezone.now() - timedelta(hours=IdempotencyRecord.RETENTION_HOURS)
        IdempotencyRecord.objects.filter(created_at__lt=cutoff).delete()
