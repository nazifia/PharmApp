#!/usr/bin/env python
import os
import sys
from pathlib import Path


def main():
    # Allow .active_env file (written by admin SiteConfig toggle) to override default.
    # An explicit DJANGO_SETTINGS_MODULE env var always wins over the file.
    if 'DJANGO_SETTINGS_MODULE' not in os.environ:
        _env_file = Path(__file__).resolve().parent / '.active_env'
        if _env_file.exists():
            os.environ['DJANGO_SETTINGS_MODULE'] = _env_file.read_text().strip()
        else:
            os.environ['DJANGO_SETTINGS_MODULE'] = 'pharmapi.settings.dev'

    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
