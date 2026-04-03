try:
    from whitenoise.storage import CompressedManifestStaticFilesStorage as _Base
except ImportError:
    # whitenoise is a production dependency; not installed in dev.
    # Provide a no-op base so this module is importable everywhere.
    from django.contrib.staticfiles.storage import ManifestStaticFilesStorage as _Base


class RelaxedManifestStaticFilesStorage(_Base):
    """
    Subclass of WhiteNoise's CompressedManifestStaticFilesStorage with
    manifest_strict disabled.

    By default, ManifestStaticFilesStorage raises ValueError when a static
    file is referenced (via {% static %} or storage.url()) but has no entry
    in the staticfiles.json manifest.  Jazzmin always calls
    static('vendor/bootswatch/default/bootstrap.min.css') at request time,
    even when Bootstrap is served from a CDN and the bootswatch file is not
    present on the server.  With manifest_strict=False, missing entries
    silently fall back to the unhashed path instead of raising a 500.
    """
    manifest_strict = False
