"""
Org data backup & restore.

GET  /auth/org/backup/          — dump every model row belonging to the
                                  caller's organization as one JSON attachment.
POST /auth/org/backup/restore/  — upsert rows from a previously exported
                                  backup file back into the caller's org.
Admin/Manager only.
"""
import json

from django.apps import apps
from django.core.serializers.json import DjangoJSONEncoder
from django.db import connection, transaction
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .permissions import IsAdminOrManager
from .utils import log_activity, require_org

# Never export credential material.
_SENSITIVE_FIELDS = {'password'}


def _field_value(field, obj):
    value = field.value_from_object(obj)
    # FieldFile (logos, receipts) → stored path string
    if hasattr(value, 'storage'):
        return value.name or None
    return value


def _serialize_row(obj):
    return {
        f.name: _field_value(f, obj)
        for f in obj._meta.fields
        if f.name not in _SENSITIVE_FIELDS
    }


def build_org_backup(org, exported_by=''):
    """Return the full backup dict for one organization."""
    tables = {}
    # ponytail: full-table scan per model; paginate/stream if orgs outgrow memory
    for model in apps.get_models():
        field_names = {f.name for f in model._meta.fields}
        if 'organization' not in field_names:
            continue
        label = f'{model._meta.app_label}.{model._meta.model_name}'
        tables[label] = [
            _serialize_row(obj)
            for obj in model.objects.filter(organization=org).iterator()
        ]

    return {
        'meta': {
            'format_version': 1,
            'exported_at': timezone.now().isoformat(),
            'exported_by': exported_by,
            'organization_id': org.id,
            'organization_name': org.name,
            'row_counts': {k: len(v) for k, v in tables.items()},
        },
        'organization': _serialize_row(org),
        'tables': tables,
    }


def backup_http_response(org, exported_by=''):
    """Backup dict rendered as a downloadable JSON attachment."""
    data = build_org_backup(org, exported_by=exported_by)
    payload = json.dumps(data, cls=DjangoJSONEncoder, ensure_ascii=False, default=str)
    stamp = timezone.localdate().isoformat()
    response = HttpResponse(payload, content_type='application/json')
    response['Content-Disposition'] = (
        f'attachment; filename="pharmapp_backup_{org.slug}_{stamp}.json"'
    )
    return response


def restore_org_backup(org, data):
    """
    Upsert rows from a backup dict into `org`. Returns per-table results.
    Raises ValueError for files that are not version-1 PharmApp backups.
    """
    meta = data.get('meta') if isinstance(data, dict) else None
    if not meta or meta.get('format_version') != 1 or 'tables' not in data:
        raise ValueError('Not a PharmApp backup file.')

    model_map = {
        f'{m._meta.app_label}.{m._meta.model_name}': m
        for m in apps.get_models()
    }

    results = {}
    with transaction.atomic():
        # Rows arrive in arbitrary FK order; defer checks, verify at the end.
        with connection.constraint_checks_disabled():
            for label, rows in data['tables'].items():
                model = model_map.get(label)
                if model is None:
                    results[label] = {'skipped': len(rows), 'reason': 'unknown model'}
                    continue
                fields = {f.name: f for f in model._meta.fields}
                if 'organization' not in fields:
                    results[label] = {'skipped': len(rows), 'reason': 'not org-scoped'}
                    continue

                created = updated = skipped = 0
                for row in rows:
                    pk = row.get('id')
                    if pk is None:
                        skipped += 1
                        continue
                    # Never overwrite a row that belongs to another org.
                    existing = model.objects.filter(pk=pk).first()
                    if existing is not None and existing.organization_id not in (org.id, None):
                        skipped += 1
                        continue

                    defaults = {}
                    for name, value in row.items():
                        f = fields.get(name)
                        if f is None or f.primary_key or name in ('organization', *_SENSITIVE_FIELDS):
                            continue
                        defaults[f.attname if f.is_relation else name] = value
                    defaults['organization_id'] = org.id

                    _, was_created = model.objects.update_or_create(pk=pk, defaults=defaults)
                    if was_created:
                        created += 1
                    else:
                        updated += 1
                results[label] = {'created': created, 'updated': updated, 'skipped': skipped}

        connection.check_constraints()
    return results


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminOrManager])
def org_backup_view(request):
    org, err = require_org(request)
    if err:
        return err
    log_activity(request, action='Backup', category='settings',
                 description='Exported organization data backup')
    return backup_http_response(org, exported_by=getattr(request.user, 'phone_number', ''))


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAdminOrManager])
def org_restore_view(request):
    org, err = require_org(request)
    if err:
        return err

    # Accept multipart upload ("file") or raw JSON body.
    upload = request.FILES.get('file')
    try:
        data = json.load(upload) if upload else request.data
    except (json.JSONDecodeError, UnicodeDecodeError):
        return Response({'detail': 'Invalid backup file: not valid JSON.'},
                        status=status.HTTP_400_BAD_REQUEST)

    try:
        results = restore_org_backup(org, data)
    except ValueError as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    log_activity(request, action='Restore', category='settings',
                 description='Restored organization data from backup')
    return Response({'detail': 'Restore complete.', 'results': results})
