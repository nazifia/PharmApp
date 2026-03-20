from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/',      include('authapp.urls')),
    path('api/inventory/', include('inventory.urls')),
    path('api/customers/', include('customers.urls')),
    path('api/pos/',       include('pos.urls')),
    path('api/reports/',   include('reports.urls')),
]
