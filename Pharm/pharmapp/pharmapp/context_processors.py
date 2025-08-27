from django.conf import settings

def vapid_public_key(request):
    return {
        "VAPID_PUBLIC_KEY": settings.WEBPUSH_SETTINGS.get("VAPID_PUBLIC_KEY")
    }
