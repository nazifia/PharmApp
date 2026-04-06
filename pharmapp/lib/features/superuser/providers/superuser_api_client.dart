import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';

class SuperuserApiClient {
  final Dio _dio;
  SuperuserApiClient(this._dio);

  /// GET /superuser/organizations/
  /// Returns all organizations with their subscription info.
  Future<List<OrgSubscriptionSummary>> listOrganizations() async {
    final res = await _dio.get('/superuser/organizations/');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => OrgSubscriptionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /superuser/organizations/{id}/
  Future<OrgSubscriptionSummary> getOrganization(int id) async {
    final res = await _dio.get('/superuser/organizations/$id/');
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// PATCH /superuser/organizations/{id}/subscription/
  /// Override plan, status, trial, features, and limits for a specific org.
  Future<OrgSubscriptionSummary> updateOrgSubscription(
    int orgId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch(
      '/superuser/organizations/$orgId/subscription/',
      data: payload,
    );
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /superuser/organizations/{id}/extend-trial/
  /// Extend trial by [days] days from now.
  Future<OrgSubscriptionSummary> extendTrial(int orgId, int days) async {
    final res = await _dio.post(
      '/superuser/organizations/$orgId/extend-trial/',
      data: {'days': days},
    );
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /superuser/organizations/{id}/reset-subscription/
  /// Reset overrides back to plan defaults.
  Future<OrgSubscriptionSummary> resetToDefaults(int orgId) async {
    final res = await _dio.post(
      '/superuser/organizations/$orgId/reset-subscription/',
    );
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }
}

final superuserApiClientProvider = Provider<SuperuserApiClient>((ref) {
  return SuperuserApiClient(ref.watch(dioProvider));
});
