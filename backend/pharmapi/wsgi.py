import os
from pathlib import Path
from django.core.wsgi import get_wsgi_application

# Allow .active_env file (written by admin SiteConfig toggle) to override default.
# An explicit DJANGO_SETTINGS_MODULE env var always wins over the file.
if 'DJANGO_SETTINGS_MODULE' not in os.environ:
    _env_file = Path(__file__).resolve().parent.parent / '.active_env'
    if _env_file.exists():
        os.environ['DJANGO_SETTINGS_MODULE'] = _env_file.read_text().strip()
    else:
        os.environ['DJANGO_SETTINGS_MODULE'] = 'pharmapi.settings.prod'

application = get_wsgi_application()
