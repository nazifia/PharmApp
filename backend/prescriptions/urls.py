from django.urls import path
from . import views

urlpatterns = [
    # Prescriptions
    path('portal/',                       views.prescriber_portal_create_rx, name='prescriber-portal-rx'),
    path('',                              views.prescription_list,        name='prescription-list'),
    path('network/',                      views.network_prescriptions,    name='prescription-network'),
    path('pending-count/',                views.pending_count,            name='prescription-pending-count'),
    path('<int:pk>/',                     views.prescription_detail,      name='prescription-detail'),
    path('<int:pk>/dispense/',            views.dispense_prescription,    name='prescription-dispense'),
    path('customer/<int:customer_pk>/',   views.customer_prescriptions,   name='customer-prescriptions'),
    path('by-phone/',                     views.prescriptions_by_phone,   name='prescriptions-by-phone'),

    # Prescribers (global — no org scope)
    path('prescribers/',                  views.prescriber_list,          name='prescriber-list'),
    path('prescribers/register/',         views.prescriber_register,      name='prescriber-register'),
    path('prescribers/login/',            views.prescriber_login,         name='prescriber-login'),
    path('prescribers/<int:pk>/',         views.prescriber_detail,        name='prescriber-detail'),
    path('prescribers/<int:pk>/patients/', views.prescriber_patients,          name='prescriber-patients'),
    path('prescribers/<int:pk>/commissions/',         views.prescriber_commissions,          name='prescriber-commissions'),
    path('prescribers/<int:pk>/commissions/summary/', views.prescriber_commission_summary,    name='prescriber-commission-summary'),
    path('prescribers/<int:pk>/commissions/<int:commission_id>/', views.prescriber_commission_mark_paid, name='prescriber-commission-mark-paid'),
    path('prescribers/<int:pk>/commissions/pay-all/',             views.prescriber_commission_pay_all,   name='prescriber-commission-pay-all'),

    # Hospitals (global)
    path('hospitals/',                    views.hospital_list,            name='hospital-list'),
    path('hospitals/<int:pk>/',           views.hospital_detail,          name='hospital-detail'),
]
