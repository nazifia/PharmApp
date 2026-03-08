from django.urls import path
from . import views

urlpatterns = [
    path('',                                      views.customer_list,       name='customer-list'),
    path('<int:pk>/',                             views.customer_detail,     name='customer-detail'),
    path('<int:pk>/wallet/transactions/',         views.wallet_transactions, name='wallet-txns'),
    path('<int:pk>/wallet/topup/',                views.wallet_topup,        name='wallet-topup'),
    path('<int:pk>/wallet/deduct/',               views.wallet_deduct,       name='wallet-deduct'),
    path('<int:pk>/sales/',                       views.customer_sales,      name='customer-sales'),
]
