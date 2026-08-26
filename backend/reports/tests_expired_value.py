"""Expired-stock valuation in the inventory report.

Expired = expiry date strictly before today. Value is the cost basis (the real
write-off); retail value is what the stock would have sold for. Items expiring
within 30 days are counted separately as at-risk, never as expired.
"""
from datetime import timedelta
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from inventory.models import Item
from reports.views import inventory_report


class ExpiredStockValueTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000002", password="pass1234", role="Admin",
            organization=self.org,
        )
        self.today = timezone.localdate()

    def _item(self, name, cost, price, stock, expiry):
        return Item.objects.create(
            organization=self.org, name=name, cost=Decimal(str(cost)),
            price=Decimal(str(price)), stock=Decimal(str(stock)),
            expiry_date=expiry, store="retail",
        )

    def _report(self):
        req = self.factory.get("/api/reports/inventory/")
        force_authenticate(req, user=self.user)
        return inventory_report(req).data

    def test_expired_value_uses_cost_basis_and_excludes_live_stock(self):
        self._item("Expired A", 60, 100, 10, self.today - timedelta(days=5))
        self._item("Expired B", 25, 40, 4, self.today - timedelta(days=200))
        self._item("Expiring", 50, 90, 6, self.today + timedelta(days=10))
        self._item("Fresh", 30, 70, 100, self.today + timedelta(days=365))
        self._item("No expiry", 30, 70, 100, None)

        data = self._report()

        self.assertEqual(data["expiredCount"], 2)
        self.assertEqual(data["expiredValue"], 60 * 10 + 25 * 4)      # 700
        self.assertEqual(data["expiredRetailValue"], 100 * 10 + 40 * 4)  # 1160
        self.assertEqual(data["expiringCount"], 1)
        self.assertEqual(data["expiringValue"], 50 * 6)               # 300
        self.assertEqual(len(data["expiredItems"]), 2)
        self.assertEqual(data["expiredItems"][0]["name"], "Expired B")  # oldest first
        self.assertEqual(data["expiredItems"][0]["daysExpired"], 200)

    def test_expiring_today_is_not_yet_expired(self):
        self._item("Today", 10, 20, 5, self.today)
        data = self._report()
        self.assertEqual(data["expiredCount"], 0)
        self.assertEqual(data["expiredValue"], 0)
        self.assertEqual(data["expiringCount"], 1)

    def test_written_off_stock_no_longer_counts_as_expired(self):
        self._item("Written off", 60, 100, 0, self.today - timedelta(days=5))
        data = self._report()
        self.assertEqual(data["expiredCount"], 0)
        self.assertEqual(data["expiredValue"], 0)
        self.assertEqual(data["expiredItems"], [])

    def test_no_expired_stock_reports_zero(self):
        self._item("Fresh", 30, 70, 10, self.today + timedelta(days=90))
        data = self._report()
        self.assertEqual(data["expiredCount"], 0)
        self.assertEqual(data["expiredValue"], 0)
        self.assertEqual(data["expiredItems"], [])
