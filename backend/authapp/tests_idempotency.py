"""Tests for IdempotencyMiddleware — replayed writes must execute once."""
from django.http import JsonResponse
from django.test import RequestFactory, TestCase

from authapp.middleware import IdempotencyMiddleware
from authapp.models import IdempotencyRecord


class IdempotencyMiddlewareTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.calls = 0

    def _middleware(self, status=201):
        def view(request):
            self.calls += 1
            return JsonResponse({'id': self.calls}, status=status)
        return IdempotencyMiddleware(view)

    def _post(self, key=None, path='/api/pos/checkout/', method='post'):
        headers = {'HTTP_IDEMPOTENCY_KEY': key} if key else {}
        request = getattr(self.factory, method)(path, **headers)
        return request

    def test_same_key_executes_once_and_replays_response(self):
        mw = self._middleware()
        first = mw(self._post(key='device-1:42'))
        second = mw(self._post(key='device-1:42'))

        self.assertEqual(self.calls, 1)
        self.assertEqual(second.status_code, first.status_code)
        self.assertEqual(second.content, first.content)
        self.assertEqual(second['Idempotency-Replayed'], 'true')

    def test_different_keys_both_execute(self):
        mw = self._middleware()
        mw(self._post(key='device-1:42'))
        mw(self._post(key='device-1:43'))

        self.assertEqual(self.calls, 2)

    def test_request_without_key_is_untouched(self):
        mw = self._middleware()
        mw(self._post())
        mw(self._post())

        self.assertEqual(self.calls, 2)
        self.assertEqual(IdempotencyRecord.objects.count(), 0)

    def test_get_with_key_is_not_deduplicated(self):
        mw = self._middleware(status=200)
        mw(self._post(key='device-1:42', method='get'))
        mw(self._post(key='device-1:42', method='get'))

        self.assertEqual(self.calls, 2)

    def test_server_error_releases_the_key(self):
        mw = self._middleware(status=500)
        mw(self._post(key='device-1:42'))
        self.assertEqual(IdempotencyRecord.objects.count(), 0)

        # A retry of the same key must actually run — nothing was applied.
        mw(self._post(key='device-1:42'))
        self.assertEqual(self.calls, 2)

    def test_view_exception_releases_the_key(self):
        def boom(request):
            self.calls += 1
            raise ValueError('kaboom')

        mw = IdempotencyMiddleware(boom)
        with self.assertRaises(ValueError):
            mw(self._post(key='device-1:42'))
        self.assertEqual(IdempotencyRecord.objects.count(), 0)

    def test_in_flight_key_gets_409(self):
        # Original request claimed the key but has not stored a response yet.
        IdempotencyRecord.objects.create(
            key='device-1:42', method='POST', path='/api/pos/checkout/')
        mw = self._middleware()
        response = mw(self._post(key='device-1:42'))

        self.assertEqual(response.status_code, 409)
        self.assertEqual(self.calls, 0)

    def test_non_api_path_is_untouched(self):
        mw = self._middleware()
        mw(self._post(key='device-1:42', path='/admin/something/'))
        mw(self._post(key='device-1:42', path='/admin/something/'))

        self.assertEqual(self.calls, 2)
