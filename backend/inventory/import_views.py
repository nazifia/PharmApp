"""Bulk item import from an uploaded CSV, Excel or PDF file."""
from django.db import transaction
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.utils import require_org, log_activity
from authapp.permissions import IsInventoryEditor

from .importers import (
    COLUMN_ALIASES, ImportParseError, parse_file, to_date, to_decimal,
)
from .models import Item, DOSAGE_FORM_CHOICES, UNIT_CHOICES, STORE_CHOICES

MAX_IMPORT_BYTES = 5 * 1024 * 1024
MAX_IMPORT_ROWS = 5000

_TEXT_FIELDS = ("brand", "barcode", "batch_number")
_MONEY_FIELDS = ("cost", "price", "markup", "stock")
_INT_FIELDS = ("low_stock_threshold", "reorder_level")


def _match_choice(value, choices, default=""):
    """Case-insensitive lookup of a free-text value against a choices list."""
    text = str(value or "").strip()
    if not text:
        return default
    for stored, _label in choices:
        if stored.lower() == text.lower():
            return stored
    return default


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated, IsInventoryEditor])
@parser_classes([MultiPartParser, FormParser])
def bulk_import(request):
    """Create or update items in bulk from an uploaded file.

    GET  /inventory/items/bulk-import/
        Returns the accepted column headings so the client can show a template.

    POST /inventory/items/bulk-import/   (multipart/form-data)
        file        the CSV / .xlsx / .pdf price list or stock sheet
        dryRun      "true" to validate and preview without writing anything
        store       "retail" (default) or "wholesale" for rows with no store column
        stockMode   "replace" (default) sets stock to the file's value;
                    "add" treats the file as a delivery and adds to current stock
        branchId    optional branch to attach newly created items to

    Existing items are matched on barcode when the row has one, otherwise on name
    within the same store, so re-uploading a corrected sheet updates rather than
    duplicates. Only the columns present in the file are touched.
    """
    org, err = require_org(request)
    if err:
        return err

    if request.method == "GET":
        return Response({
            "columns": [
                {"field": field, "required": field == "name",
                 "acceptedHeadings": aliases}
                for field, aliases in COLUMN_ALIASES.items()
            ],
            "template": "name,brand,dosage_form,unit,cost,price,stock,barcode,"
                        "batch_number,expiry_date,store",
            "maxRows": MAX_IMPORT_ROWS,
            "maxBytes": MAX_IMPORT_BYTES,
        })

    upload = request.FILES.get("file")
    if upload is None:
        return Response({"detail": "No file was uploaded."},
                        status=status.HTTP_400_BAD_REQUEST)
    if upload.size > MAX_IMPORT_BYTES:
        return Response(
            {"detail": "File is too large. The limit is %dMB."
                       % (MAX_IMPORT_BYTES // (1024 * 1024))},
            status=status.HTTP_400_BAD_REQUEST)

    def flag(*keys):
        return any(str(request.data.get(k, "")).strip().lower() in ("1", "true", "yes")
                   for k in keys)

    dry_run = flag("dryRun", "dry_run")
    stock_mode = str(request.data.get("stockMode")
                     or request.data.get("stock_mode") or "replace").lower()
    if stock_mode not in ("replace", "add"):
        return Response({"detail": "stockMode must be 'replace' or 'add'."},
                        status=status.HTTP_400_BAD_REQUEST)
    default_store = str(request.data.get("store") or "retail").lower()
    if default_store not in ("retail", "wholesale"):
        default_store = "retail"

    branch = None
    branch_id = request.data.get("branchId") or request.data.get("branch_id")
    if branch_id:
        try:
            from branches.models import Branch
            branch = Branch.objects.get(pk=int(branch_id), organization=org)
        except Exception:
            branch = None

    try:
        rows = parse_file(upload.name, upload.read(), max_rows=MAX_IMPORT_ROWS)
    except ImportParseError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as exc:
        return Response({"detail": "Could not read the file: %s" % exc},
                        status=status.HTTP_400_BAD_REQUEST)

    created, updated, errors, preview = 0, 0, [], []

    try:
        with transaction.atomic():
            for offset, row in enumerate(rows):
                line = offset + 2  # +1 for the header row, +1 for 1-based numbering
                name = str(row.get("name") or "").strip()[:200]
                store = _match_choice(row.get("store"), STORE_CHOICES, default_store)

                values, bad_field = {}, None
                for field in _TEXT_FIELDS:
                    if field in row:
                        values[field] = str(row.get(field) or "").strip()[:100]
                for field in _MONEY_FIELDS:
                    if field not in row:
                        continue
                    number = to_decimal(row.get(field))
                    if number is None:
                        if str(row.get(field) or "").strip():
                            bad_field = field
                        continue
                    if number < 0:
                        bad_field = field
                        continue
                    values[field] = number
                for field in _INT_FIELDS:
                    if field in row:
                        number = to_decimal(row.get(field))
                        if number is not None and number >= 0:
                            values[field] = int(number)
                if bad_field:
                    errors.append({"row": line, "name": name,
                                   "detail": "Invalid value in '%s'." % bad_field})
                    continue
                if "dosage_form" in row:
                    values["dosage_form"] = _match_choice(
                        row["dosage_form"], DOSAGE_FORM_CHOICES)
                if "unit" in row:
                    values["unit"] = _match_choice(row["unit"], UNIT_CHOICES, "Pcs")
                if "expiry_date" in row:
                    expiry = to_date(row["expiry_date"])
                    if expiry is None and str(row["expiry_date"] or "").strip():
                        errors.append({"row": line, "name": name,
                                       "detail": "Unrecognised expiry date."})
                        continue
                    values["expiry_date"] = expiry

                barcode = str(row.get("barcode") or "").strip()
                existing = None
                if barcode:
                    existing = Item.objects.filter(
                        organization=org, barcode__iexact=barcode).first()
                if existing is None:
                    existing = Item.objects.filter(
                        organization=org, name__iexact=name, store=store).first()

                if existing is not None:
                    if stock_mode == "add" and "stock" in values:
                        values["stock"] = existing.stock + values["stock"]
                    for field, value in values.items():
                        setattr(existing, field, value)
                    existing.save()
                    updated += 1
                    item, action = existing, "update"
                else:
                    item = Item.objects.create(organization=org, branch=branch,
                                               name=name, store=store, **values)
                    created += 1
                    action = "create"

                if len(preview) < 50:
                    preview.append({
                        "row": line, "action": action, "name": item.name,
                        "store": item.store, "stock": float(item.stock),
                        "price": float(item.price), "cost": float(item.cost),
                        "expiryDate": str(item.expiry_date) if item.expiry_date else None,
                    })

            if dry_run:
                transaction.set_rollback(True)
    except Exception as exc:
        return Response({"detail": "Import failed, nothing was saved: %s" % exc},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    if not dry_run and (created or updated):
        log_activity(
            request, action="Bulk Import", category="inventory",
            description='Imported "%s": %d created, %d updated, %d skipped'
                        % (upload.name, created, updated, len(errors)))

    return Response({
        "dryRun": dry_run,
        "fileName": upload.name,
        "totalRows": len(rows),
        "created": created,
        "updated": updated,
        "skipped": len(errors),
        "errors": errors[:100],
        "preview": preview,
    })
