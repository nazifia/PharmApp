import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/subscription.dart';
// BillingInfo, BillingContact, PlatformPaymentAccount are defined in subscription.dart

class SubscriptionApiClient {
  final Dio _dio;
  SubscriptionApiClient(this._dio);

  /// GET /subscription/ — returns current org subscription.
  /// Falls back to a default trial if the endpoint is not yet deployed.
  Future<Subscription> getSubscription() async {
    try {
      final res = await _dio.get('/subscription/');
      return Subscription.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 404 means endpoint not deployed yet → return default trial
      if (e.response?.statusCode == 404) {
        return Subscription.defaultTrial();
      }
      rethrow;
    }
  }

  /// POST /subscription/upgrade/ — request a plan upgrade.
  /// [billingCycle] is 'monthly' or 'annual'.
  /// Backend should redirect to payment gateway / confirm upgrade.
  Future<Map<String, dynamic>> upgradePlan(
      String planId, String billingCycle) async {
    final res = await _dio.post('/subscription/upgrade/', data: {
      'plan_id':       planId,
      'billing_cycle': billingCycle,
    });
    return res.data as Map<String, dynamic>;
  }

  /// POST /subscription/cancel/ — cancel current subscription.
  Future<void> cancelSubscription() async {
    await _dio.post('/subscription/cancel/');
  }

  /// GET /subscription/billing/ — invoice history + payment method + next payment.
  Future<BillingInfo> getBillingInfo() async {
    try {
      final res = await _dio.get('/subscription/billing/');
      return BillingInfo.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return BillingInfo.empty();
      rethrow;
    }
  }

  /// GET /subscription/billing/portal/ — returns a Stripe/payment portal URL.
  Future<String?> getBillingPortalUrl() async {
    try {
      final res = await _dio.get('/subscription/billing/portal/');
      return (res.data as Map<String, dynamic>)['portal_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// POST /subscription/billing/contact/ — save subscriber billing contact.
  /// The backend uses this to send payment receipts (email) and
  /// reminders/confirmations (WhatsApp).
  Future<void> saveBillingContact(BillingContact contact) async {
    await _dio.post('/subscription/billing/contact/', data: contact.toJson());
  }

  /// POST /subscription/billing/payment-method/ — record card details for
  /// auto-billing. In production, send only the tokenised representation
  /// (last4, brand, expiry) — never the raw PAN.
  Future<void> savePaymentMethod({
    required String last4,
    required String brand,
    required int    expMonth,
    required int    expYear,
    required String cardholderName,
  }) async {
    await _dio.post('/subscription/billing/payment-method/', data: {
      'last4':           last4,
      'brand':           brand,
      'exp_month':       expMonth,
      'exp_year':        expYear,
      'cardholder_name': cardholderName,
    });
  }

  /// POST /subscription/billing/auto-billing/ — toggle auto-renewal on/off.
  Future<void> setAutoBilling({required bool enabled}) async {
    await _dio.post('/subscription/billing/auto-billing/',
        data: {'enabled': enabled});
  }

  /// GET /subscription/billing/receiving-account/ — platform's payment
  /// receiving account. Falls back to placeholder if not deployed.
  Future<PlatformPaymentAccount> getReceivingAccount() async {
    try {
      final res = await _dio.get('/subscription/billing/receiving-account/');
      return PlatformPaymentAccount.fromJson(
          res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return PlatformPaymentAccount.placeholder();
      }
      rethrow;
    }
  }
}

final subscriptionApiClientProvider = Provider<SubscriptionApiClient>((ref) {
  return SubscriptionApiClient(ref.watch(dioProvider));
});
