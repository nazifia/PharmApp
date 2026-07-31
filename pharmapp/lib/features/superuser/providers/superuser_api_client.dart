import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';
import 'package:pharmapp/shared/models/plan_feature_matrix.dart';

class SuperuserApiClient {
  final Dio _dio;
  SuperuserApiClient(this._dio);

  /// GET /subscription/superuser/organizations/
  /// Returns all organizations with their subscription info.
  Future<List<OrgSubscriptionSummary>> listOrganizations() async {
    final res = await _dio.get('/subscription/superuser/organizations/');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => OrgSubscriptionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /subscription/superuser/organizations/{id}/
  Future<OrgSubscriptionSummary> getOrganization(int id) async {
    final res = await _dio.get('/subscription/superuser/organizations/$id/');
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// PATCH /subscription/superuser/organizations/{id}/subscription/
  /// Override plan, status, trial, features, and limits for a specific org.
  Future<OrgSubscriptionSummary> updateOrgSubscription(
    int orgId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch(
      '/subscription/superuser/organizations/$orgId/subscription/',
      data: payload,
    );
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /subscription/superuser/organizations/{id}/extend-trial/
  /// Extend trial by [days] days from now.
  Future<OrgSubscriptionSummary> extendTrial(int orgId, int days) async {
    final res = await _dio.post(
      '/subscription/superuser/organizations/$orgId/extend-trial/',
      data: {'days': days},
    );
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /subscription/superuser/organizations/{id}/reset-subscription/
  /// Reset overrides back to plan defaults.
  Future<OrgSubscriptionSummary> resetToDefaults(int orgId) async {
    final res = await _dio.post(
      '/subscription/superuser/organizations/$orgId/reset-subscription/',
    );
    return OrgSubscriptionSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /subscription/superuser/organizations/{id}/impact/
  /// Returns record counts that would be deleted if the org is deleted.
  Future<Map<String, int>> getOrgDeletionImpact(int orgId) async {
    final res = await _dio.get('/subscription/superuser/organizations/$orgId/impact/');
    final data = res.data as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// DELETE /subscription/superuser/organizations/{id}/
  /// Permanently deletes the organization and all associated data.
  Future<void> deleteOrganization(int orgId) async {
    await _dio.delete('/subscription/superuser/organizations/$orgId/');
  }

  /// POST /auth/switch-org/
  /// Superuser only — returns { access, user } scoped to [orgId]. The new
  /// token carries an org_id claim, so every org endpoint answers with that
  /// tenant's data.
  Future<Map<String, dynamic>> switchOrg(int orgId) async {
    final res = await _dio.post('/auth/switch-org/', data: {'org_id': orgId});
    return res.data as Map<String, dynamic>;
  }

  // ── Plan Feature Matrix ────────────────────────────────────────────────────

  /// GET /subscription/superuser/plan-features/
  /// Returns the global plan → feature matrix editable by superusers.
  /// Falls back to hardcoded defaults on 404.
  Future<PlanFeatureMatrix> getPlanFeatureMatrix() async {
    try {
      final res = await _dio.get('/subscription/superuser/plan-features/');
      return PlanFeatureMatrix.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return PlanFeatureMatrix.fromDefaults();
      }
      rethrow;
    }
  }

  /// PATCH /subscription/superuser/plan-features/
  /// Saves the updated plan-feature matrix.
  Future<PlanFeatureMatrix> updatePlanFeatureMatrix(
      PlanFeatureMatrix matrix) async {
    final res = await _dio.patch(
      '/subscription/superuser/plan-features/',
      data: matrix.toJson(),
    );
    return PlanFeatureMatrix.fromJson(res.data as Map<String, dynamic>);
  }

}

final superuserApiClientProvider = Provider<SuperuserApiClient>((ref) {
  return SuperuserApiClient(ref.watch(dioProvider));
});
