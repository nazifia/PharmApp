import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/subscription.dart';
// BillingInfo is defined in subscription.dart

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
}

final subscriptionApiClientProvider = Provider<SubscriptionApiClient>((ref) {
  return SubscriptionApiClient(ref.watch(dioProvider));
});
