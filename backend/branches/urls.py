from django.urls import path
from . import views

urlpatterns = [
    path('',                         views.branch_list,       name='branch-list'),
    path('create/',                  views.branch_create,     name='branch-create'),
    path('<int:branch_id>/',         views.branch_detail,     name='branch-detail'),
    path('<int:branch_id>/update/',  views.branch_update,     name='branch-update'),
    path('<int:branch_id>/delete/',  views.branch_deactivate, name='branch-deactivate'),
    path('<int:branch_id>/set-main/', views.branch_set_main,  name='branch-set-main'),
]
