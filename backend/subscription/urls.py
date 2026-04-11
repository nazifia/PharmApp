from django.urls import path
from . import views

urlpatterns = [
    # ── Org subscription (authenticated user's own org) ────────────────────────
    path('',               views.subscription_detail,  name='subscription-detail'),
    path('payment-accounts/', views.payment_accounts,  name='payment-accounts'),
    path('upgrade/', views.subscription_upgrade, name='subscription-upgrade'),
    path('cancel/',  views.subscription_cancel,  name='subscription-cancel'),

    # ── Billing endpoints ──────────────────────────────────────────────────────
    path('billing/',                       views.billing_info,               name='billing-info'),
    path('billing/receiving-account/',     views.billing_receiving_account,  name='billing-receiving-account'),

    # ── Superuser cross-org management ────────────────────────────────────────
    path('superuser/organizations/',
         views.superuser_org_list,
         name='superuser-org-list'),
    path('superuser/organizations/<int:org_id>/',
         views.superuser_org_detail,
         name='superuser-org-detail'),
    path('superuser/organizations/<int:org_id>/subscription/',
         views.superuser_update_subscription,
         name='superuser-update-subscription'),
    path('superuser/organizations/<int:org_id>/extend-trial/',
         views.superuser_extend_trial,
         name='superuser-extend-trial'),
    path('superuser/organizations/<int:org_id>/reset-subscription/',
         views.superuser_reset_subscription,
         name='superuser-reset-subscription'),

    # ── Global plan-feature matrix ─────────────────────────────────────────────
    path('superuser/plan-features/',
         views.superuser_plan_features,
         name='superuser-plan-features'),
]
