from django.urls import path
from . import views

urlpatterns = [
    path('items/',                    views.item_list,    name='item-list'),
    path('items/<int:pk>/',           views.item_detail,  name='item-detail'),
    path('items/<int:pk>/adjust-stock/', views.adjust_stock, name='item-adjust-stock'),
]
