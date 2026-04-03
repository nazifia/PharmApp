import time

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
                from authapp.models import SiteConfig
                cfg = SiteConfig.objects.filter(pk=1).first()
                if cfg and cfg.maintenance_mode:
                    return JsonResponse(
                        {'detail': 'The system is under maintenance. Please try again later.'},
                        status=503,
                    )
            except Exception:
                pass  # DB not ready — let the request through
        return self.get_response(request)


class AdminInactivityMiddleware:
    """
    Auto-logs out admin users after 2 minutes of inactivity.
    Only applies to /admin/ paths; updates session timestamp on each request.
    """
    INACTIVITY_TIMEOUT = 120  # 2 minutes

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

        request.session['last_admin_activity'] = now
        return self.get_response(request)
