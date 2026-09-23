"""
Prescription refills: create with refills -> dispense -> refill -> dispense -> no refills left.
"""
from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from prescriptions.models import Prescription
from prescriptions.views import dispense_prescription, prescription_list, refill_prescription


class PrescriptionRefillTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000000", password="pass1234", role="Admin",
            organization=self.org,
        )

    def _call(self, method, view, data=None, **kwargs):
        req = getattr(self.factory, method)("/", data or {}, format="json")
        force_authenticate(req, user=self.user)
        return view(req, **kwargs)

    def test_refill_cycle(self):
        resp = self._call("post", prescription_list, {
            "customer_name": "Jane", "refills_allowed": 1,
            "medications": [{"item_name": "Amoxicillin", "quantity": 1, "duration": "2 weeks"}],
        })
        self.assertEqual(resp.status_code, 201, resp.data)
        pk = resp.data["id"]
        self.assertEqual(resp.data["refills_allowed"], 1)

        # Cannot refill before the first dispense.
        self.assertEqual(self._call("post", refill_prescription, pk=pk).status_code, 400)

        resp = self._call("patch", dispense_prescription, pk=pk)
        self.assertEqual(resp.data["status"], "dispensed")
        self.assertIsNotNone(resp.data["next_refill_date"])  # 14-day supply

        resp = self._call("post", refill_prescription, pk=pk)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["status"], "pending")
        self.assertEqual(resp.data["refills_used"], 1)
        self.assertFalse(resp.data["medications"][0]["is_dispensed"])

        self._call("patch", dispense_prescription, pk=pk)
        rx = Prescription.objects.get(pk=pk)
        self.assertEqual(rx.status, "dispensed")
        self.assertIsNone(rx.next_refill_date)  # no refills left, nothing due

        self.assertEqual(self._call("post", refill_prescription, pk=pk).status_code, 400)
