from django.http import JsonResponse


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
