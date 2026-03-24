from django.contrib import admin
from django.urls import path, include
from authapp.admin_views import global_overview_view

urlpatterns = [
    # Custom superuser overview — must come BEFORE the admin catch-all
    path('admin/overview/', admin.site.admin_view(global_overview_view), name='admin-global-overview'),
    path('admin/', admin.site.urls),
    path('api/auth/',      include('authapp.urls')),
    path('api/inventory/', include('inventory.urls')),
    path('api/customers/', include('customers.urls')),
    path('api/pos/',       include('pos.urls')),
    path('api/reports/',   include('reports.urls')),
]
