from django.urls import path
from . import views

urlpatterns = [
    path('',                              views.prescription_list,        name='prescription-list'),
    path('network/',                      views.network_prescriptions,    name='prescription-network'),
    path('pending-count/',                views.pending_count,            name='prescription-pending-count'),
    path('<int:pk>/',                     views.prescription_detail,      name='prescription-detail'),
    path('<int:pk>/dispense/',            views.dispense_prescription,    name='prescription-dispense'),
    path('customer/<int:customer_pk>/',   views.customer_prescriptions,   name='customer-prescriptions'),
    path('by-phone/',                     views.prescriptions_by_phone,   name='prescriptions-by-phone'),
]
