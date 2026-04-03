try:
    from whitenoise.storage import CompressedStaticFilesStorage as _Base
except ImportError:
    # whitenoise is a production dependency; not installed in dev.
    from django.contrib.staticfiles.storage import StaticFilesStorage as _Base


class CompressedNoManifestStorage(_Base):
    """
    WhiteNoise CompressedStaticFilesStorage without a manifest.

    Serves static files with gzip/brotli compression but keeps original
    filenames (no content-hash suffix).  This avoids the manifest lookup
    that CompressedManifestStaticFilesStorage performs: jazzmin always calls
    static('vendor/bootswatch/default/bootstrap.min.css') at request time
    even when Bootstrap is served via CDN, which raises ValueError when that
    file is absent from the manifest.  Without a manifest, the call simply
    returns the raw /static/ path and the browser handles the 404 silently.
    """
