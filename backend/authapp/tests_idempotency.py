"""
Replayed writes and refresh tokens.

Verifies:
- A repeated Idempotency-Key returns the stored response without running the
  view again (the duplicate-sale case the offline queue can otherwise cause).
- A different caller's Authorization header cannot replay someone else's key.
- A failed request releases the key so a genuine retry still reaches the view.
- Login hands out a refresh token, and it can be traded for a new access token.
"""
from django.http import JsonResponse
from django.test import TestCase, RequestFactory
from rest_framework.test import APIClient

from authapp.middleware import IdempotencyMiddleware
from authapp.models import Organization, PharmUser


class IdempotencyMiddlewareTest(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.calls = 0

    def _middleware(self, status=201):
        def view(request):
            self.calls += 1
            return JsonResponse({'id': self.calls}, status=status)
        return IdempotencyMiddleware(view)

    def _post(self, key, auth='Bearer aaa'):
        return self.factory.post('/api/pos/checkout/', HTTP_IDEMPOTENCY_KEY=key,
                                 HTTP_AUTHORIZATION=auth)

    def test_replay_returns_stored_response_without_rerunning_view(self):
        mw = self._middleware()
        first = mw(self._post('key-1'))
        second = mw(self._post('key-1'))
        self.assertEqual(self.calls, 1)
        self.assertEqual(first.status_code, second.status_code)
        self.assertEqual(first.content, second.content)

    def test_other_caller_cannot_replay_the_same_key(self):
        mw = self._middleware()
        mw(self._post('key-1', auth='Bearer aaa'))
        mw(self._post('key-1', auth='Bearer bbb'))
        self.assertEqual(self.calls, 2)

    def test_failed_request_releases_the_key(self):
        mw = self._middleware(status=400)
        mw(self._post('key-1'))
        mw(self._post('key-1'))
        self.assertEqual(self.calls, 2)

    def test_request_without_key_is_untouched(self):
        mw = self._middleware()
        mw(self.factory.post('/api/pos/checkout/'))
        mw(self.factory.post('/api/pos/checkout/'))
        self.assertEqual(self.calls, 2)


class RefreshTokenTest(TestCase):
    def setUp(self):
        self.org = Organization.objects.create(name="Alpha Pharmacy")
        PharmUser.objects.create_user(
            phone_number="08000000002", password="pass1234",
            organization=self.org, role="Admin")
        self.client = APIClient()

    def test_login_returns_refresh_token_that_mints_a_new_access_token(self):
        res = self.client.post('/api/auth/login/', {
            'phone_number': '08000000002', 'password': 'pass1234'}, format='json')
        self.assertEqual(res.status_code, 200)
        refresh = res.data.get('refresh')
        self.assertTrue(refresh)

        res2 = self.client.post('/api/auth/refresh/', {'refresh': refresh},
                                format='json')
        self.assertEqual(res2.status_code, 200)
        self.assertTrue(res2.data.get('access'))

        # The renewed token must actually authenticate.
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {res2.data['access']}")
        self.assertEqual(self.client.get('/api/auth/me/').status_code, 200)


class InflightTakeoverTest(TestCase):
    """An abandoned in-flight key must not answer 409 forever."""

    def setUp(self):
        self.factory = RequestFactory()
        self.calls = 0

    def _middleware(self):
        def view(request):
            self.calls += 1
            return JsonResponse({'id': self.calls}, status=201)
        return IdempotencyMiddleware(view)

    def _post(self, key='key-1'):
        return self.factory.post('/api/pos/checkout/', HTTP_IDEMPOTENCY_KEY=key,
                                 HTTP_AUTHORIZATION='Bearer aaa')

    def test_fresh_inflight_key_is_rejected_as_duplicate(self):
        from authapp.models import IdempotencyRecord
        import hashlib
        IdempotencyRecord.objects.create(
            key='key-1',
            token_hash=hashlib.sha256(b'Bearer aaa').hexdigest()[:64])
        res = self._middleware()(self._post())
        self.assertEqual(res.status_code, 409)
        self.assertEqual(self.calls, 0)

    def test_abandoned_inflight_key_is_taken_over(self):
        from datetime import timedelta
        import hashlib
        from django.utils import timezone
        from authapp.models import IdempotencyRecord

        rec = IdempotencyRecord.objects.create(
            key='key-1',
            token_hash=hashlib.sha256(b'Bearer aaa').hexdigest()[:64])
        IdempotencyRecord.objects.filter(pk=rec.pk).update(
            created_at=timezone.now() - timedelta(
                seconds=IdempotencyMiddleware.INFLIGHT_TAKEOVER_SECONDS + 1))

        res = self._middleware()(self._post())
        self.assertEqual(res.status_code, 201)
        self.assertEqual(self.calls, 1)
        rec.refresh_from_db()
        self.assertEqual(rec.status_code, 201)
