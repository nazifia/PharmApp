"""
Superuser cross-tenant access.

Verifies:
- A superuser with no org of their own is told to pick one (403 select_org).
- The existing org list (/subscription/superuser/organizations/) is superuser-only.
- /auth/switch-org/ mints a token whose org_id claim scopes org-only views.
- A non-superuser cannot switch, and a forged org_id claim on a normal user's
  token is ignored (they stay inside their own org).
"""
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from authapp.models import Organization, PharmUser
from inventory.models import Item


class SuperuserTenantAccessTest(TestCase):
    def setUp(self):
        self.org_a = Organization.objects.create(name="Alpha Pharmacy")
        self.org_b = Organization.objects.create(name="Beta Pharmacy")
        self.root = PharmUser.objects.create_superuser(
            phone_number="08000000001", password="pass1234")
        self.staff = PharmUser.objects.create_user(
            phone_number="08000000002", password="pass1234", role="Admin",
            organization=self.org_a)
        Item.objects.create(organization=self.org_a, name="Alpha Drug",
                            price=10, cost=5, stock=1, store="retail")
        Item.objects.create(organization=self.org_b, name="Beta Drug",
                            price=10, cost=5, stock=1, store="retail")

    def _client(self, user, org_id=None):
        refresh = RefreshToken.for_user(user)
        if org_id:
            refresh['org_id'] = org_id
        c = APIClient()
        c.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        return c

    def test_superuser_without_org_is_asked_to_pick_one(self):
        res = self._client(self.root).get('/api/inventory/items/')
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data.get('code'), 'select_org')

    def test_org_list_is_superuser_only(self):
        res = self._client(self.root).get('/api/subscription/superuser/organizations/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 2)
        self.assertEqual(
            self._client(self.staff)
            .get('/api/subscription/superuser/organizations/').status_code, 403)

    def test_switch_org_scopes_every_org_view(self):
        c = self._client(self.root)
        res = c.post('/api/auth/switch-org/', {'org_id': self.org_b.id}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['user']['organizationId'], self.org_b.id)

        c.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")
        self.assertEqual(c.get('/api/auth/me/').data['organizationName'], "Beta Pharmacy")
        names = [i['name'] for i in c.get('/api/inventory/items/').data]
        self.assertEqual(names, ["Beta Drug"])

        # switching again moves to the other tenant
        res = c.post('/api/auth/switch-org/', {'org_id': self.org_a.id}, format='json')
        c.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")
        names = [i['name'] for i in c.get('/api/inventory/items/').data]
        self.assertEqual(names, ["Alpha Drug"])

    def test_normal_user_cannot_cross_tenants(self):
        c = self._client(self.staff, org_id=self.org_b.id)  # forged claim
        names = [i['name'] for i in c.get('/api/inventory/items/').data]
        self.assertEqual(names, ["Alpha Drug"])
        self.assertEqual(
            c.post('/api/auth/switch-org/', {'org_id': self.org_b.id},
                   format='json').status_code, 403)
