from django import template
from authapp.models import SiteConfig
from subscription.models import Subscription

register = template.Library()


@register.inclusion_tag('admin/authapp/siteconfig/_env_banner.html')
def env_banner():
    return {
        'running_env':    SiteConfig.running_env(),
        'pending_env':    SiteConfig.pending_env(),
        'pending_subs':   Subscription.objects.filter(status='pending').count(),
    }
