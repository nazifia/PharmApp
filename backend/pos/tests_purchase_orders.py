"""
Purchase-order lifecycle: create -> submit -> partial receive -> full receive.

Verifies stock is added only for what arrives, and over-receiving is capped at
the ordered quantity (a re-sent request must not inflate stock).
"""
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from inventory.models import Item
from pos.models import Supplier
from pos.purchase_order_views import (
    purchase_order_list, purchase_order_receive, purchase_order_submit,
)


class PurchaseOrderTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000000", password="pass1234", role="Admin",
            organization=self.org,
        )
        self.supplier = Supplier.objects.create(organization=self.org, name="MedSupply")
        self.item = Item.objects.create(
            organization=self.org, name="Paracetamol", price=Decimal("100"),
            cost=Decimal("50"), stock=Decimal("10"), store="retail",
        )

    def _call(self, view, data, **kwargs):
        req = self.factory.post("/", data, format="json")
        force_authenticate(req, user=self.user)
        return view(req, **kwargs)

    def test_lifecycle_adds_stock_and_caps_over_receive(self):
        resp = self._call(purchase_order_list, {
            "supplier_id": self.supplier.id,
            "items": [{"item_id": self.item.id, "item_name": "Paracetamol",
                       "quantity_ordered": 20, "unit_cost": 45}],
        })
        self.assertEqual(resp.status_code, 201)
        po_id = resp.data["id"]
        line_id = resp.data["items"][0]["id"]

        # Receiving a draft is rejected.
        resp = self._call(purchase_order_receive,
                          {"items": [{"id": line_id, "quantity_received": 5}]}, pk=po_id)
        self.assertEqual(resp.status_code, 400)

        self.assertEqual(self._call(purchase_order_submit, {}, pk=po_id).data["status"], "submitted")

        resp = self._call(purchase_order_receive,
                          {"items": [{"id": line_id, "quantity_received": 5}]}, pk=po_id)
        self.assertEqual(resp.data["status"], "partial")
        self.item.refresh_from_db()
        self.assertEqual(self.item.stock, Decimal("15"))
        self.assertEqual(self.item.cost, Decimal("45"))

        # Asks for 50 but only 15 are outstanding.
        resp = self._call(purchase_order_receive,
                          {"items": [{"id": line_id, "quantity_received": 50}]}, pk=po_id)
        self.assertEqual(resp.data["status"], "received")
        self.item.refresh_from_db()
        self.assertEqual(self.item.stock, Decimal("30"))

    def test_other_org_supplier_rejected(self):
        other = Organization.objects.create(name="Other")
        foreign = Supplier.objects.create(organization=other, name="X")
        resp = self._call(purchase_order_list, {
            "supplier_id": foreign.id,
            "items": [{"item_id": self.item.id, "quantity_ordered": 1, "unit_cost": 1}],
        })
        self.assertEqual(resp.status_code, 400)
