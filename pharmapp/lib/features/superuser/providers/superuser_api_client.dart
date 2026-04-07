import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';
import 'package:pharmapp/shared/models/plan_feature_matrix.dart';

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

  // ── Plan Feature Matrix ────────────────────────────────────────────────────

  /// GET /superuser/plan-features/
  /// Returns the global plan → feature matrix editable by superusers.
  /// Falls back to hardcoded defaults on 404.
  Future<PlanFeatureMatrix> getPlanFeatureMatrix() async {
    try {
      final res = await _dio.get('/superuser/plan-features/');
      return PlanFeatureMatrix.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return PlanFeatureMatrix.fromDefaults();
      }
      rethrow;
    }
  }

  /// PATCH /superuser/plan-features/
  /// Saves the updated plan-feature matrix.
  Future<PlanFeatureMatrix> updatePlanFeatureMatrix(
      PlanFeatureMatrix matrix) async {
    final res = await _dio.patch(
      '/superuser/plan-features/',
      data: matrix.toJson(),
    );
    return PlanFeatureMatrix.fromJson(res.data as Map<String, dynamic>);
  }
}

final superuserApiClientProvider = Provider<SuperuserApiClient>((ref) {
  return SuperuserApiClient(ref.watch(dioProvider));
});
