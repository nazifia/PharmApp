import time

from django.core.cache import cache
from django.http import JsonResponse
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
