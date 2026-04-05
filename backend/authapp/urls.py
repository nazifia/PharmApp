from django.urls import path
from . import views

urlpatterns = [
    path('login/',                              views.login_view,             name='auth-login'),
    path('me/',                                 views.me_view,                name='auth-me'),
    path('register-org/',                       views.register_org_view,      name='auth-register-org'),
    path('org/logo/',                           views.org_logo_view,          name='auth-org-logo'),
    path('users/<int:user_id>/permissions/',    views.user_permissions_view,  name='auth-user-permissions'),
]
