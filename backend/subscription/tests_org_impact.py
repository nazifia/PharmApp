"""
Deletion-impact preview for a superuser.

Verifies the endpoint counts the org's own cascading rows, reports SET_NULL
relations (users) as kept rather than deleted, never counts another tenant's
data, deletes nothing, and stays superuser-only.
"""
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from authapp.models import Organization, PharmUser
from customers.models import Customer
from inventory.models import Item


class OrgDeletionImpactTest(TestCase):
    def setUp(self):
        self.org = Organization.objects.create(name="Alpha Pharmacy")
        self.other = Organization.objects.create(name="Beta Pharmacy")
        self.root = PharmUser.objects.create_superuser(
            phone_number="08000000001", password="pass1234")
        self.staff = PharmUser.objects.create_user(
            phone_number="08000000002", password="pass1234", role="Admin",
            organization=self.org)
        for org, n in ((self.org, 3), (self.other, 5)):
            for i in range(n):
                Item.objects.create(organization=org, name=f"Drug {org.id}-{i}",
                                    price=10, cost=5, stock=1, store="retail")
        Customer.objects.create(organization=self.org, name="Jane", phone="0811")

    def _client(self, user):
        c = APIClient()
        c.credentials(
            HTTP_AUTHORIZATION=f'Bearer {RefreshToken.for_user(user).access_token}')
        return c

    def test_impact_counts_only_this_org(self):
        res = self._client(self.root).get(
            f'/api/subscription/superuser/organizations/{self.org.id}/impact/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data.get('items'), 3)
        self.assertEqual(res.data.get('customers'), 1)
        # PharmUser.organization is SET_NULL — users are kept, not deleted.
        self.assertEqual(res.data.get('pharm users unlinked (kept)'), 1)
        self.assertNotIn('organizations', res.data)

        # preview only — nothing was removed
        self.assertEqual(Item.objects.count(), 8)
        self.assertTrue(Organization.objects.filter(pk=self.org.id).exists())

    def test_requires_superuser_and_real_org(self):
        self.assertEqual(
            self._client(self.staff).get(
                f'/api/subscription/superuser/organizations/{self.org.id}/impact/'
            ).status_code, 403)
        self.assertEqual(
            self._client(self.root).get(
                '/api/subscription/superuser/organizations/99999/impact/'
            ).status_code, 404)

    def test_delete_removes_only_this_org(self):
        url = f'/api/subscription/superuser/organizations/{self.org.id}/'
        # non-superuser cannot delete
        self.assertEqual(self._client(self.staff).delete(url).status_code, 403)

        self.assertEqual(self._client(self.root).delete(url).status_code, 204)
        self.assertFalse(Organization.objects.filter(pk=self.org.id).exists())
        self.assertEqual(Item.objects.count(), 5)          # only Beta's remain
        self.assertEqual(Customer.objects.count(), 0)
        self.staff.refresh_from_db()                       # SET_NULL: user kept
        self.assertIsNone(self.staff.organization_id)

        self.assertEqual(self._client(self.root).delete(url).status_code, 404)

    def test_cannot_delete_own_org(self):
        self.root.organization = self.org
        self.root.save(update_fields=['organization'])
        res = self._client(self.root).delete(
            f'/api/subscription/superuser/organizations/{self.org.id}/')
        self.assertEqual(res.status_code, 400)
        self.assertTrue(Organization.objects.filter(pk=self.org.id).exists())
