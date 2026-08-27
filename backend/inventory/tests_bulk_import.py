"""Bulk item import.

An import writes many rows at once, so the parts worth pinning down are: loose
header spellings still map to the right fields, messy money and date values are
coerced rather than saved wrong, a re-upload updates instead of duplicating, a
dry run writes nothing, and a bad row is skipped without taking the batch down.
"""
from decimal import Decimal

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from inventory.import_views import bulk_import
from inventory.importers import parse_file, to_date, to_decimal
from inventory.models import Item


class ImportParsingTest(TestCase):
    """The pure parsing helpers, no database involved."""

    def test_money_strips_symbols_and_separators(self):
        self.assertEqual(to_decimal("N1,200.50"), Decimal("1200.50"))
        self.assertEqual(to_decimal("  450 "), Decimal("450"))
        self.assertEqual(to_decimal(""), None)
        self.assertEqual(to_decimal("not a price"), None)

    def test_dates_accept_the_common_spellings(self):
        self.assertEqual(str(to_date("2026-03-15")), "2026-03-15")
        self.assertEqual(str(to_date("15/03/2026")), "2026-03-15")
        # month-only expiry means the end of that month
        self.assertEqual(str(to_date("03/2026")), "2026-03-31")
        self.assertEqual(str(to_date("12/2026")), "2026-12-31")
        self.assertIsNone(to_date("sometime soon"))

    def test_headers_match_loosely_and_junk_rows_above_are_skipped(self):
        blob = (
            b"ACME DISTRIBUTORS PRICE LIST\n"
            b"Product Name,Selling Price,Qty,Exp Date\n"
            b"Paracetamol 500mg,250,40,03/2026\n"
        )
        rows = parse_file("list.csv", blob)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["name"], "Paracetamol 500mg")
        self.assertEqual(rows[0]["price"], "250")
        self.assertEqual(rows[0]["stock"], "40")

    def test_unsupported_and_headerless_files_are_rejected(self):
        with self.assertRaises(Exception):
            parse_file("scan.docx", b"whatever")
        with self.assertRaises(Exception):
            parse_file("list.csv", b"a,b,c\n1,2,3\n")


class BulkImportEndpointTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.other_org = Organization.objects.create(name="Other Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000009", password="pass1234", role="Admin",
            organization=self.org,
        )

    def _upload(self, text, name="items.csv", **extra):
        body = {"file": SimpleUploadedFile(name, text.encode(), "text/csv")}
        body.update(extra)
        req = self.factory.post("/api/inventory/items/bulk-import/", body,
                                format="multipart")
        force_authenticate(req, user=self.user)
        return bulk_import(req)

    def test_creates_items_with_coerced_values(self):
        res = self._upload(
            "name,brand,price,cost,qty,expiry\n"
            "Paracetamol,Emzor,\"1,200.00\",800,25,03/2026\n"
            "Amoxil,GSK,500,300,10,2026-12-01\n"
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["created"], 2)
        self.assertEqual(res.data["skipped"], 0)
        item = Item.objects.get(organization=self.org, name="Paracetamol")
        self.assertEqual(item.price, Decimal("1200.00"))
        self.assertEqual(item.stock, Decimal("25"))
        self.assertEqual(str(item.expiry_date), "2026-03-31")
        self.assertEqual(item.store, "retail")

    def test_reupload_updates_instead_of_duplicating(self):
        self._upload("name,price,qty\nParacetamol,1000,10\n")
        res = self._upload("name,price,qty\nparacetamol,1500,4\n")
        self.assertEqual(res.data["created"], 0)
        self.assertEqual(res.data["updated"], 1)
        self.assertEqual(Item.objects.filter(organization=self.org).count(), 1)
        item = Item.objects.get(organization=self.org)
        self.assertEqual(item.price, Decimal("1500"))
        self.assertEqual(item.stock, Decimal("4"))

    def test_stock_mode_add_treats_the_file_as_a_delivery(self):
        self._upload("name,qty\nParacetamol,10\n")
        res = self._upload("name,qty\nParacetamol,15\n", stockMode="add")
        self.assertEqual(res.data["updated"], 1)
        self.assertEqual(Item.objects.get(organization=self.org).stock, Decimal("25"))

    def test_dry_run_reports_without_writing(self):
        res = self._upload("name,price,qty\nParacetamol,1000,10\n", dryRun="true")
        self.assertTrue(res.data["dryRun"])
        self.assertEqual(res.data["created"], 1)
        self.assertEqual(res.data["preview"][0]["action"], "create")
        self.assertEqual(Item.objects.count(), 0)

    def test_bad_rows_are_skipped_and_reported_not_fatal(self):
        res = self._upload(
            "name,price,qty,expiry\n"
            "Good Item,100,5,2026-01-01\n"
            "Bad Price,abc,5,2026-01-01\n"
            "Bad Date,100,5,whenever\n"
        )
        self.assertEqual(res.data["created"], 1)
        self.assertEqual(res.data["skipped"], 2)
        self.assertEqual(
            {e["name"] for e in res.data["errors"]}, {"Bad Price", "Bad Date"})
        self.assertTrue(Item.objects.filter(name="Good Item").exists())

    def test_match_stays_inside_the_callers_organization(self):
        Item.objects.create(organization=self.other_org, name="Paracetamol",
                            store="retail", price=Decimal("9"))
        res = self._upload("name,price\nParacetamol,1000\n")
        self.assertEqual(res.data["created"], 1)
        self.assertEqual(
            Item.objects.get(organization=self.other_org).price, Decimal("9"))

    def test_get_returns_the_column_template(self):
        req = self.factory.get("/api/inventory/items/bulk-import/")
        force_authenticate(req, user=self.user)
        res = bulk_import(req)
        self.assertEqual(res.status_code, 200)
        self.assertIn("name", res.data["template"])
        self.assertTrue(any(c["required"] for c in res.data["columns"]))
