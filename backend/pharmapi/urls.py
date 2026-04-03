from django.contrib import admin
from django.http import HttpResponse
from django.http import JsonResponse
from django.urls import path, include
from authapp.admin_views import global_overview_view
from subscription.admin_views import saas_dashboard_view


def _empty_sw(request):
    """Silence browser requests for a service worker at the root."""
    return HttpResponse('/* no service worker */', content_type='application/javascript')


urlpatterns = [
    # Suppress browser service-worker 404 noise
    path('sw.js', _empty_sw),

    # Custom superuser views — must come BEFORE the admin catch-all
    path('admin/overview/',              admin.site.admin_view(global_overview_view), name='admin-global-overview'),
    path('admin/subscription/dashboard/', admin.site.admin_view(saas_dashboard_view),  name='admin-saas-dashboard'),
    path('admin/', admin.site.urls),
    path('api/auth/',      include('authapp.urls')),
    path('api/inventory/', include('inventory.urls')),
    path('api/customers/', include('customers.urls')),
    path('api/pos/',       include('pos.urls')),
    path('api/reports/',      include('reports.urls')),
    path('api/subscription/', include('subscription.urls')),
    path('api/', lambda request: JsonResponse({
        "message": "PharmApp API is working",
        "endpoints": [
            "/api/auth/",
            "/api/inventory/",
            "/api/customers/",
            "/api/pos/",
            "/api/reports/",
            "/api/subscription/"
        ]
    })),
]