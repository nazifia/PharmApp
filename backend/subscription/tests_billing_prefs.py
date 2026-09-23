"""Billing contact: validation and round-trip through billing info."""
from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from authapp.models import Organization, PharmUser
from subscription.views import billing_contact, billing_info


class BillingContactTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.org = Organization.objects.create(name="Test Pharmacy")
        self.user = PharmUser.objects.create_user(
            phone_number="08000000000", password="pass1234", role="Admin",
            organization=self.org,
        )

    def _call(self, view, method="post", data=None):
        req = getattr(self.factory, method)("/", data or {}, format="json")
        force_authenticate(req, user=self.user)
        return view(req)

    def test_contact_saved_and_returned(self):
        self.assertEqual(self._call(billing_contact, data={"email": "not-an-email"}).status_code, 400)
        self.assertEqual(self._call(billing_contact, data={}).status_code, 400)

        ok = self._call(billing_contact, data={"email": "a@b.co", "whats_app": "+2348012345678"})
        self.assertEqual(ok.status_code, 200)

        info = self._call(billing_info, method="get")
        self.assertEqual(info.data["billing_contact"]["email"], "a@b.co")
        self.assertNotIn("payment_method", info.data)
