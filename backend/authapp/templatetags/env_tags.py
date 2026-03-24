from django import template
from authapp.models import SiteConfig

register = template.Library()


@register.inclusion_tag('admin/authapp/siteconfig/_env_banner.html')
def env_banner():
    return {
        'running_env':    SiteConfig.running_env(),
        'pending_env':    SiteConfig.pending_env(),
        'restart_needed': SiteConfig.restart_needed(),
    }
