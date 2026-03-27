from django.urls import path
from . import views

urlpatterns = [
    path('',        views.subscription_detail,  name='subscription-detail'),
    path('upgrade/', views.subscription_upgrade, name='subscription-upgrade'),
    path('cancel/',  views.subscription_cancel,  name='subscription-cancel'),
]
