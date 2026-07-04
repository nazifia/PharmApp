"""
Wallet-credit sales logic.

Verifies:
- A wallet sale with SUFFICIENT balance is booked 'completed' and counts toward
  the daily sales total / revenue.
- A wallet sale with INSUFFICIENT balance is booked 'credit': still dispensed and
  logged as a customer wallet transaction, but excluded from the sales total.
- Wallet top-ups show up in the report's "received" wallet bucket (money in),
  while wallet spends do not (they are prepaid).
"""
from decimal import Decimal

from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from customers.models import Customer, WalletTransaction
from inventory.models import Item
from pos.models import Sale
from pos.views import checkout
from reports.views import sales_report


class WalletCreditSalesTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000000", password="pass1234", role="Admin",
            organization=self.org,
        )
        self.customer = Customer.objects.create(
            organization=self.org, name="Jane", phone="0811", wallet_balance=Decimal("1000"),
        )
        self.item = Item.objects.create(
            organization=self.org, name="Paracetamol", price=Decimal("100"),
            cost=Decimal("50"), stock=Decimal("100"), store="retail",
        )

    def _checkout(self, wallet):
        req = self.factory.post("/api/pos/checkout/", {
            "customerId": self.customer.id,
            "items": [{"itemId": self.item.id, "quantity": 1, "price": 500}],
            "payment": {"wallet": wallet},
            "paymentMethod": "wallet",
        }, format="json")
        force_authenticate(req, user=self.user)
        return checkout(req)

    def test_sufficient_wallet_counts(self):
        resp = self._checkout(500)
        self.assertEqual(resp.status_code, 201)
        sale = Sale.objects.get(pk=resp.data["id"])
        self.assertEqual(sale.status, "completed")

    def test_insufficient_wallet_is_credit_and_excluded(self):
        # balance 1000, wallet spend 2000 -> insufficient
        resp = self._checkout(2000)
        self.assertEqual(resp.status_code, 201)
        sale = Sale.objects.get(pk=resp.data["id"])
        self.assertEqual(sale.status, "credit")
        # recorded in the customer's wallet transactions (debt)
        self.assertTrue(
            self.customer.wallet_transactions.filter(txn_type="purchase", amount=2000).exists()
        )
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.wallet_balance, Decimal("-1000"))

        # excluded from daily sales total, surfaced as a credit line
        report = self._sales_report()
        self.assertEqual(report["totalRevenue"], 0.0)
        self.assertEqual(report["creditCount"], 1)
        self.assertEqual(report["creditSales"], 500.0)

    def test_topup_counts_as_received(self):
        WalletTransaction.objects.create(
            customer=self.customer, txn_type="topup", amount=Decimal("3000"),
        )
        report = self._sales_report()
        self.assertEqual(report["todayPaymentMethods"]["wallet"], 3000.0)

    def _sales_report(self):
        req = self.factory.get("/api/reports/sales/", {"period": "today"})
        force_authenticate(req, user=self.user)
        resp = sales_report(req)
        return resp.data
