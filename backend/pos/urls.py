from django.urls import path
from . import views
from . import wholesale_views

urlpatterns = [
    # Checkout & Sales
    path("checkout/", views.checkout, name="pos-checkout"),
    path("sales/", views.sale_list, name="pos-sale-list"),
    path("sales/<int:pk>/", views.sale_detail, name="pos-sale-detail"),
    path("sales/<int:pk>/return/", views.return_item, name="pos-return-item"),
    # Payment Requests (Dispenser -> Cashier)
    path("payment-requests/", views.payment_request_list, name="pr-list"),
    path("payment-requests/send/", views.send_to_cashier, name="pr-send"),
    path(
        "payment-requests/<int:pk>/accept/",
        views.accept_payment_request,
        name="pr-accept",
    ),
    path(
        "payment-requests/<int:pk>/reject/",
        views.reject_payment_request,
        name="pr-reject",
    ),
    path(
        "payment-requests/<int:pk>/complete/",
        views.complete_payment_request,
        name="pr-complete",
    ),
    # Dispensing Log
    path("dispensing-log/", views.dispensing_log_list, name="dispensing-log"),
    path("dispensing-stats/", views.dispensing_stats, name="dispensing-stats"),
    # Expenses
    path("expense-categories/", views.expense_category_list, name="expense-cat-list"),
    path("expenses/", views.expense_list, name="expense-list"),
    path("expenses/<int:pk>/", views.expense_detail, name="expense-detail"),
    path("monthly-report/", views.monthly_report, name="monthly-report"),
    # Suppliers & Procurement
    path("suppliers/", views.supplier_list, name="supplier-list"),
    path("suppliers/<int:pk>/", views.supplier_detail, name="supplier-detail"),
    path("procurements/", views.procurement_list, name="procurement-list"),
    path(
        "procurements/<int:pk>/complete/",
        views.complete_procurement,
        name="procurement-complete",
    ),
    # Stock Check
    path("stock-checks/", views.stock_check_list, name="sc-list"),
    path("stock-checks/<int:pk>/", views.stock_check_detail, name="sc-detail"),
    path(
        "stock-checks/<int:pk>/add-item/",
        views.stock_check_add_item,
        name="sc-add-item",
    ),
    path(
        "stock-checks/<int:pk>/items/",
        views.stock_check_add_item,
        name="sc-items-add",
    ),
    path(
        "stock-checks/<int:pk>/items/<int:item_pk>/",
        views.stock_check_update_item,
        name="sc-update-item",
    ),
    path(
        "stock-checks/<int:pk>/approve/", views.stock_check_approve, name="sc-approve"
    ),
    path("stock-checks/<int:pk>/delete/", views.stock_check_delete, name="sc-delete"),
    # Cashiers
    path("cashiers/", views.cashier_list, name="cashier-list"),
    # Notifications
    path("notifications/", views.notification_list, name="notif-list"),
    path("notifications/count/", views.notification_count, name="notif-count"),
    path("notifications/<int:pk>/read/", views.notification_read, name="notif-read"),
    # Barcode
    path("barcode/lookup/", views.barcode_lookup, name="barcode-lookup"),
    # User Management
    path("users/", views.user_list, name="user-list"),
    path("users/<int:pk>/", views.user_detail, name="user-detail"),
    path(
        "users/<int:pk>/change-password/",
        views.change_password,
        name="user-change-password",
    ),
    # ── Wholesale ──────────────────────────────────────────────────────────────
    path(
        "wholesale/dashboard/", wholesale_views.wholesale_dashboard, name="ws-dashboard"
    ),
    path(
        "wholesale/customers/",
        wholesale_views.wholesale_customer_list,
        name="ws-customers",
    ),
    path(
        "wholesale/customers/negative/",
        wholesale_views.wholesale_customer_negative,
        name="ws-customers-negative",
    ),
    path("wholesale/sales/", wholesale_views.wholesale_sale_list, name="ws-sales"),
    path(
        "wholesale/sales/by-user/",
        wholesale_views.wholesale_sale_by_user,
        name="ws-sales-by-user",
    ),
    path(
        "wholesale/sales/<int:pk>/",
        wholesale_views.wholesale_sale_detail,
        name="ws-sale-detail",
    ),
    path(
        "wholesale/sales/<int:pk>/return/",
        wholesale_views.wholesale_sale_return,
        name="ws-sale-return",
    ),
    path("wholesale/transfers/", wholesale_views.transfer_list, name="ws-transfers"),
    path(
        "wholesale/transfers/<int:pk>/",
        wholesale_views.transfer_detail,
        name="ws-transfer-detail",
    ),
    path(
        "wholesale/transfers/<int:pk>/approve/",
        wholesale_views.transfer_approve,
        name="ws-transfer-approve",
    ),
    path(
        "wholesale/transfers/<int:pk>/reject/",
        wholesale_views.transfer_reject,
        name="ws-transfer-reject",
    ),
    path(
        "wholesale/transfers/<int:pk>/receive/",
        wholesale_views.transfer_receive,
        name="ws-transfer-receive",
    ),
    path(
        "wholesale/low-stock/", wholesale_views.wholesale_low_stock, name="ws-low-stock"
    ),
    path(
        "wholesale/expiry-alert/",
        wholesale_views.wholesale_expiry_alert,
        name="ws-expiry-alert",
    ),
    path(
        "wholesale/inventory-value/",
        wholesale_views.wholesale_inventory_value,
        name="ws-inventory-value",
    ),
]
