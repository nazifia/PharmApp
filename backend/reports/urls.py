from django.urls import path
from . import views

urlpatterns = [
    path('sales/',          views.sales_report,          name='report-sales'),
    path('inventory/',      views.inventory_report,       name='report-inventory'),
    path('customers/',      views.customer_report,        name='report-customers'),
    path('profit/',         views.profit_report,          name='report-profit'),
    path('cashier-sales/',  views.cashier_sales_report,   name='report-cashier-sales'),
]
