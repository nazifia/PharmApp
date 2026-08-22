"""Profit calculation.

Verifies the three ways the old maths was wrong:
- COGS read Item.cost live, so editing a cost price rewrote past profit.
- Returned units were counted in both revenue and COGS.
- One costed line among many made the whole report look fully costed, so
  uncosted revenue was reported as pure profit.
"""
from datetime import timedelta
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from inventory.models import Item
from pos.models import ReturnRecord, Sale, SaleItem
from pos.views import checkout, return_item
from reports.views import profit_report


class ProfitCalculationTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000001", password="pass1234", role="Admin",
            organization=self.org,
        )
        self.item = Item.objects.create(
            organization=self.org, name="Paracetamol", price=Decimal("100"),
            cost=Decimal("60"), stock=Decimal("100"), store="retail",
        )

    def _checkout(self, item, qty, unit_price):
        total = Decimal(str(unit_price)) * qty
        req = self.factory.post("/api/pos/checkout/", {
            "items": [{"itemId": item.id, "quantity": qty, "price": float(unit_price)}],
            "payment": {"cash": float(total)},
            "paymentMethod": "cash",
            "total": float(total),
        }, format="json")
        force_authenticate(req, user=self.user)
        res = checkout(req)
        self.assertIn(res.status_code, (200, 201), res.data)
        return Sale.objects.get(pk=res.data["id"])

    def _return(self, sale, qty):
        line = sale.items.first()
        # snake_case on purpose: that is what the app actually sends.
        req = self.factory.post(f"/api/pos/sales/{sale.pk}/return/", {
            "sale_item_id": line.pk, "quantity": qty, "refund_method": "cash",
        }, format="json")
        force_authenticate(req, user=self.user)
        self.assertEqual(return_item(req, sale.pk).status_code, 200)
        return ReturnRecord.objects.filter(sale=sale).latest("pk")

    def _profit(self, **params):
        req = self.factory.get(
            "/api/reports/profit/", {"period": "today", **params})
        force_authenticate(req, user=self.user)
        return profit_report(req).data

    def test_cost_is_snapshotted_at_checkout(self):
        self._checkout(self.item, 2, 100)          # revenue 200, cost 120
        self.item.cost = Decimal("90")             # supplier price rises later
        self.item.save()

        data = self._profit()
        assert data["cost"] == 120.0, data          # not 180 — snapshot held
        assert data["profit"] == 80.0, data
        assert data["margin"] == 40.0, data
        assert data["costCoverage"] == 1.0, data

    def test_returned_units_leave_revenue_and_cogs(self):
        sale = self._checkout(self.item, 5, 100)   # revenue 500, cost 300
        self._return(sale, 2)

        data = self._profit()                       # 3 units kept
        assert data["revenue"] == 300.0, data
        assert data["cost"] == 180.0, data
        assert data["profit"] == 120.0, data

    def test_same_day_full_return_nets_to_zero(self):
        sale = self._checkout(self.item, 2, 100)
        self._return(sale, 2)

        sale.refresh_from_db()
        assert sale.status == "returned", sale.status
        data = self._profit()
        assert data["revenue"] == 0.0, data
        assert data["cost"] == 0.0, data
        assert data["profit"] == 0.0, data

    def test_refund_hits_the_period_it_was_recorded_in(self):
        """A refund must not reach back and rewrite a closed month."""
        sale = self._checkout(self.item, 5, 100)     # today: 500 rev, 300 cost
        ret = self._return(sale, 2)
        # Backdate the refund to last month, leaving the sale where it is.
        last_month = timezone.now() - timedelta(days=31)
        ReturnRecord.objects.filter(pk=ret.pk).update(created_at=last_month)

        today = self._profit()
        assert today["revenue"] == 500.0, today      # sale period untouched
        assert today["cost"] == 300.0, today
        assert today["refunds"] == 0.0, today

        day = str(last_month.date())
        prior = self._profit(**{"from": day, "to": day})
        assert prior["refunds"] == 200.0, prior      # refund lands on its date
        assert prior["revenue"] == -200.0, prior
        assert prior["cost"] == -120.0, prior

    def test_uncosted_lines_are_flagged_not_counted_as_free(self):
        free = Item.objects.create(
            organization=self.org, name="Vitamin C", price=Decimal("100"),
            cost=Decimal("0"), stock=Decimal("100"), store="retail",
        )
        self._checkout(self.item, 1, 100)          # costed: 100 rev / 60 cost
        self._checkout(free, 3, 100)               # uncosted: 300 rev / no cost

        data = self._profit()
        assert data["revenue"] == 400.0, data
        assert data["cost"] == 60.0, data
        # Coverage says only a quarter of line revenue has a cost price, so the
        # 340 "profit" is known to be overstated instead of silently trusted.
        assert data["costCoverage"] == 0.25, data
        assert data["estimated"] is False, data

    def test_no_cost_data_anywhere_is_marked_estimated(self):
        free = Item.objects.create(
            organization=self.org, name="Vitamin C", price=Decimal("100"),
            cost=Decimal("0"), stock=Decimal("100"), store="retail",
        )
        self._checkout(free, 2, 100)

        data = self._profit()
        assert data["cost"] == 0.0, data
        assert data["costCoverage"] == 0.0, data
        assert data["estimated"] is True, data
