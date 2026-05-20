from django.urls import path
from . import views
from . import network_views as nv

urlpatterns = [
    path('login/',                              views.login_view,             name='auth-login'),
    path('me/',                                 views.me_view,                name='auth-me'),
    path('register-org/',                       views.register_org_view,      name='auth-register-org'),
    path('org/',                                 views.org_view,               name='auth-org'),
    path('org/logo/',                           views.org_logo_view,          name='auth-org-logo'),
    path('users/<int:user_id>/permissions/',    views.user_permissions_view,  name='auth-user-permissions'),
    path('activity-log/',                       views.activity_log_view,      name='auth-activity-log'),

    # ── Pharmacy networks ─────────────────────────────────────────────────────
    path('networks/',                                          nv.network_list,          name='network-list'),
    path('networks/join-default/',                             nv.network_join_default,  name='network-join-default'),
    path('networks/<int:network_id>/',                         nv.network_detail,        name='network-detail'),
    path('networks/<int:network_id>/invite/',                  nv.network_invite,        name='network-invite'),
    path('networks/<int:network_id>/accept/',                  nv.network_accept,        name='network-accept'),
    path('networks/<int:network_id>/decline/',                 nv.network_decline,       name='network-decline'),
    path('networks/<int:network_id>/leave/',                   nv.network_leave,         name='network-leave'),
    path('networks/<int:network_id>/members/<int:org_id>/',    nv.network_remove_member, name='network-remove-member'),
]
