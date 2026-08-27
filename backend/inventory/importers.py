"""Turn an uploaded CSV / Excel / PDF file into plain item dicts.

The parsers only produce rows; validating and saving them is the view's job.
Column headers are matched loosely (case, spacing and punctuation are ignored)
because supplier price lists never agree on a spelling.
"""
import csv
import io
import re
from datetime import date, datetime, timedelta
from decimal import Decimal, InvalidOperation

_ONE_DAY = timedelta(days=1)


class ImportParseError(Exception):
    """The file could not be read at all - bad format, missing library, no rows."""


# --- header matching ---------------------------------------------------------

# canonical field -> accepted header spellings (normalised: lowercase, alnum only)
COLUMN_ALIASES = {
    "name": ["name", "item", "itemname", "product", "productname", "drug",
             "drugname", "description", "medicine", "particulars"],
    "brand": ["brand", "manufacturer", "maker", "make"],
    "dosage_form": ["dosageform", "form", "dosage", "type"],
    "unit": ["unit", "uom", "unitofdispensing", "unitofmeasure", "units"],
    "cost": ["cost", "costprice", "buyingprice", "purchaseprice", "unitcost",
             "buyprice", "rate"],
    "price": ["price", "sellingprice", "sellprice", "retailprice", "unitprice",
              "sp", "amount"],
    "markup": ["markup", "markuppercent", "markuppercentage"],
    "stock": ["stock", "qty", "quantity", "quantityinstock", "onhand",
              "stockonhand", "count", "instock", "qtyreceived"],
    "low_stock_threshold": ["lowstockthreshold", "lowstock", "minstock",
                            "minimumstock", "reorderthreshold", "minqty"],
    "reorder_level": ["reorderlevel", "reorderpoint", "reorderqty"],
    "barcode": ["barcode", "ean", "ean13", "upc", "sku", "code", "itemcode"],
    "batch_number": ["batch", "batchno", "batchnumber", "lot", "lotno",
                     "lotnumber"],
    "expiry_date": ["expiry", "expirydate", "expdate", "exp",
                    "expirationdate", "expires", "bestbefore"],
    "store": ["store", "storetype", "channel", "section"],
}

REQUIRED_COLUMNS = ["name"]

_HEADER_LOOKUP = {
    alias: field for field, aliases in COLUMN_ALIASES.items() for alias in aliases
}


def _normalise_header(value):
    return re.sub(r"[^a-z0-9]", "", str(value or "").lower())


def map_headers(header_row):
    """[raw header, ...] -> {column index: canonical field}."""
    mapping = {}
    for index, raw in enumerate(header_row):
        field = _HEADER_LOOKUP.get(_normalise_header(raw))
        if field and field not in mapping.values():
            mapping[index] = field
    return mapping


# --- value coercion ----------------------------------------------------------

_MONEY_JUNK = re.compile(r"[^\d.\-]")

_DATE_FORMATS = [
    "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%d-%m-%Y", "%d.%m.%Y",
    "%d/%m/%y", "%m/%Y", "%m-%Y", "%b %Y", "%B %Y", "%d %b %Y", "%d %B %Y",
]


def to_decimal(value, default=None):
    """Money-ish text to Decimal, ignoring currency symbols and thousand separators.

    Returns `default` when the value is blank or unreadable.
    """
    if value is None or value == "":
        return default
    if isinstance(value, (int, float, Decimal)):
        return Decimal(str(value))
    cleaned = _MONEY_JUNK.sub("", str(value).strip())
    if cleaned in ("", "-", ".", "-."):
        return default
    try:
        return Decimal(cleaned)
    except InvalidOperation:
        return default


def to_date(value):
    """Parse the date spellings that turn up in price lists. None when unreadable.

    A month-only value (03/2026) means the end of that month, which is how
    pharmaceutical expiry dates are printed.
    """
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value).strip()
    for fmt in _DATE_FORMATS:
        try:
            parsed = datetime.strptime(text, fmt).date()
        except ValueError:
            continue
        if "%d" not in fmt:  # month-only -> last day of that month
            if parsed.month == 12:
                return date(parsed.year, 12, 31)
            return date(parsed.year, parsed.month + 1, 1) - _ONE_DAY
        return parsed
    return None


# --- per-format parsers ------------------------------------------------------

def _rows_from_csv(blob):
    try:
        text = blob.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = blob.decode("latin-1", errors="replace")
    try:
        dialect = csv.Sniffer().sniff(text[:4096], delimiters=",;\t|")
    except csv.Error:
        dialect = csv.excel
    return [row for row in csv.reader(io.StringIO(text), dialect)
            if any(str(cell).strip() for cell in row)]


def _rows_from_excel(blob):
    try:
        import openpyxl
    except ImportError:
        raise ImportParseError(
            "Excel support is not installed on the server. "
            "Install openpyxl, or re-save the file as CSV."
        )
    try:
        book = openpyxl.load_workbook(io.BytesIO(blob), read_only=True, data_only=True)
    except Exception as exc:
        raise ImportParseError("Could not read the Excel file: %s" % exc)
    rows = []
    try:
        for row in book.worksheets[0].iter_rows(values_only=True):
            if any(str(cell).strip() for cell in row if cell is not None):
                rows.append(list(row))
    finally:
        book.close()
    return rows


def _rows_from_pdf(blob):
    """Best-effort table extraction. Only works on PDFs with real ruled tables."""
    try:
        import pdfplumber
    except ImportError:
        raise ImportParseError(
            "PDF support is not installed on the server. "
            "Install pdfplumber, or export the document as CSV or Excel."
        )
    rows = []
    header_signature = None
    try:
        with pdfplumber.open(io.BytesIO(blob)) as pdf:
            for page in pdf.pages:
                for table in page.extract_tables() or []:
                    for row in table:
                        cells = [(cell or "").strip() for cell in row]
                        if not any(cells):
                            continue
                        if header_signature is None:
                            header_signature = cells
                        elif cells == header_signature:
                            continue  # header repeated at the top of a later page
                        rows.append(cells)
    except Exception as exc:
        raise ImportParseError("Could not read the PDF: %s" % exc)
    return rows


_PARSERS = {
    "csv": _rows_from_csv, "txt": _rows_from_csv, "tsv": _rows_from_csv,
    "xlsx": _rows_from_excel, "xlsm": _rows_from_excel,
    "pdf": _rows_from_pdf,
}

SUPPORTED_EXTENSIONS = sorted(_PARSERS)


def parse_file(filename, blob, max_rows=5000):
    """(filename, bytes) -> list of {canonical field: raw value} dicts.

    Raises ImportParseError when the format is unsupported or the file has no
    usable header row.
    """
    extension = (filename or "").rsplit(".", 1)[-1].lower()
    parser = _PARSERS.get(extension)
    if parser is None:
        if extension == "xls":
            raise ImportParseError(
                "Old .xls files are not supported. Re-save the sheet as .xlsx or CSV."
            )
        raise ImportParseError(
            "Unsupported file type. Upload a CSV, Excel (.xlsx) or PDF file."
        )

    rows = parser(blob)
    if not rows:
        raise ImportParseError("The file is empty.")

    # The header is the first row that maps to at least one known column, so a
    # title or logo block above the table is skipped.
    header_index, mapping = None, {}
    for index, row in enumerate(rows[:20]):
        candidate = map_headers(row)
        if candidate:
            header_index, mapping = index, candidate
            break
    if header_index is None:
        raise ImportParseError(
            "No recognisable column headings were found. The file needs a header "
            "row containing at least a 'name' column."
        )
    missing = [c for c in REQUIRED_COLUMNS if c not in mapping.values()]
    if missing:
        raise ImportParseError("Missing required column(s): %s." % ", ".join(missing))

    parsed = []
    for row in rows[header_index + 1:][:max_rows]:
        record = {}
        for index, field in mapping.items():
            if index < len(row):
                value = row[index]
                record[field] = value.strip() if isinstance(value, str) else value
        if str(record.get("name") or "").strip():
            parsed.append(record)
    if not parsed:
        raise ImportParseError("The file has headings but no data rows.")
    return parsed
