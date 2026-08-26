"""Writing off expired stock.

Zeroing expired stock is destructive, so the endpoint must touch only expired
items with stock left, stay inside the caller's organisation, and report the
cost value it removed.
"""
from datetime import timedelta
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from inventory.models import Item, STATUS_ACTIVE, STATUS_INACTIVE
from inventory.views import write_off_expired


class WriteOffExpiredTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.other_org = Organization.objects.create(name="Other Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000003", password="pass1234", role="Admin",
            organization=self.org,
        )
        self.today = timezone.localdate()

    def _item(self, name, cost, price, stock, expiry, org=None):
        return Item.objects.create(
            organization=org or self.org, name=name, cost=Decimal(str(cost)),
            price=Decimal(str(price)), stock=Decimal(str(stock)),
            expiry_date=expiry, store="retail", status=STATUS_ACTIVE,
        )

    def _post(self, body=None):
        req = self.factory.post("/api/inventory/write-off-expired/", body or {},
                                format="json")
        force_authenticate(req, user=self.user)
        return write_off_expired(req).data

    def test_writes_off_only_expired_stock_and_reports_value(self):
        expired = self._item("Expired", 60, 100, 10, self.today - timedelta(days=5))
        fresh = self._item("Fresh", 30, 70, 20, self.today + timedelta(days=90))
        no_expiry = self._item("No expiry", 30, 70, 20, None)

        data = self._post()

        self.assertEqual(data["count"], 1)
        self.assertEqual(data["costValue"], 600)
        self.assertEqual(data["retailValue"], 1000)

        expired.refresh_from_db()
        fresh.refresh_from_db()
        no_expiry.refresh_from_db()
        self.assertEqual(expired.stock, 0)
        self.assertEqual(expired.status, STATUS_INACTIVE)
        self.assertEqual(fresh.stock, 20)
        self.assertEqual(no_expiry.stock, 20)

    def test_item_ids_limits_the_write_off(self):
        keep = self._item("Keep", 10, 20, 5, self.today - timedelta(days=1))
        drop = self._item("Drop", 10, 20, 7, self.today - timedelta(days=1))

        data = self._post({"itemIds": [drop.id]})

        self.assertEqual(data["count"], 1)
        keep.refresh_from_db()
        drop.refresh_from_db()
        self.assertEqual(keep.stock, 5)
        self.assertEqual(drop.stock, 0)

    def test_other_organisations_stock_is_untouched(self):
        theirs = self._item("Theirs", 10, 20, 9, self.today - timedelta(days=3),
                            org=self.other_org)

        data = self._post({"itemIds": [theirs.id]})

        self.assertEqual(data["count"], 0)
        self.assertEqual(data["costValue"], 0.0)
        theirs.refresh_from_db()
        self.assertEqual(theirs.stock, 9)

    def test_already_written_off_stock_is_a_no_op(self):
        self._item("Empty", 10, 20, 0, self.today - timedelta(days=3))
        data = self._post()
        self.assertEqual(data["count"], 0)
        self.assertEqual(data["items"], [])
