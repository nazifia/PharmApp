/// Global plan → feature matrix model used by the superuser layer.
library;

import 'package:pharmapp/shared/models/subscription.dart';

class PlanFeatureMatrix {
  /// Map from plan name (e.g. 'trial') to the set of feature keys it includes.
  final Map<String, Set<String>> planFeatures;

  /// Human-readable labels for feature keys.
  final Map<String, String> featureLabels;

  /// Ordered list of feature keys for display.
  final List<String> featureOrder;

  const PlanFeatureMatrix({
    required this.planFeatures,
    required this.featureLabels,
    required this.featureOrder,
  });

  // ── Defaults ───────────────────────────────────────────────────────────────

  factory PlanFeatureMatrix.fromDefaults() {
    final allKeys = [
      SaasFeature.pos,
      SaasFeature.inventory,
      SaasFeature.customers,
      SaasFeature.userManagement,
      SaasFeature.basicReports,
      SaasFeature.advancedReports,
      SaasFeature.wholesale,
      SaasFeature.exportData,
      SaasFeature.multiBranch,
      SaasFeature.prioritySupport,
    ];
    return PlanFeatureMatrix(
      planFeatures: {
        for (final p in SubscriptionPlan.values)
          p.name: SaasFeature.forPlan(p),
      },
      featureLabels: {for (final k in allKeys) k: SaasFeature.labelFor(k)},
      featureOrder: allKeys,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  factory PlanFeatureMatrix.fromJson(Map<String, dynamic> json) {
    final pf = (json['plan_features'] as Map<String, dynamic>? ?? {}).map(
      (k, v) =>
          MapEntry(k, (v as List<dynamic>).map((e) => e as String).toSet()),
    );
    final fl = (json['feature_labels'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as String),
    );
    final fo =
        (json['feature_order'] as List<dynamic>?)?.cast<String>() ?? [];
    return PlanFeatureMatrix(
      planFeatures: pf,
      featureLabels: fl,
      featureOrder: fo,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_features':
            planFeatures.map((k, v) => MapEntry(k, v.toList())),
        'feature_labels': featureLabels,
        'feature_order': featureOrder,
      };

  // ── Immutable mutations ────────────────────────────────────────────────────

  /// Returns a copy with [feature] added to [planName]'s feature set.
  PlanFeatureMatrix withFeatureInPlan(String planName, String feature) {
    final updated = _deepCopyPlanFeatures()
      ..[planName] = {...(planFeatures[planName] ?? {}), feature};
    return _copyWith(planFeatures: updated);
  }

  /// Returns a copy with [feature] removed from [planName]'s feature set.
  PlanFeatureMatrix withoutFeatureInPlan(String planName, String feature) {
    final updated = _deepCopyPlanFeatures();
    updated[planName]?.remove(feature);
    return _copyWith(planFeatures: updated);
  }

  /// Returns a copy with [feature] toggled in [planName].
  PlanFeatureMatrix withToggledFeatureInPlan(
      String planName, String feature) {
    return planHasFeature(planName, feature)
        ? withoutFeatureInPlan(planName, feature)
        : withFeatureInPlan(planName, feature);
  }

  /// Returns a copy with a new feature key added (not assigned to any plan yet).
  PlanFeatureMatrix withNewFeature(String key, String label) {
    if (featureOrder.contains(key)) return this; // already exists
    return _copyWith(
      featureLabels: {...featureLabels, key: label},
      featureOrder: [...featureOrder, key],
    );
  }

  /// Returns a copy with [key] removed from all plans and the feature list.
  PlanFeatureMatrix withoutFeature(String key) {
    final updatedPF = _deepCopyPlanFeatures()
      ..forEach((_, v) => v.remove(key));
    return _copyWith(
      planFeatures: updatedPF,
      featureLabels: Map.from(featureLabels)..remove(key),
      featureOrder: featureOrder.where((k) => k != key).toList(),
    );
  }

  /// Returns a copy with the display label of [key] changed to [newLabel].
  PlanFeatureMatrix withRenamedFeature(String key, String newLabel) =>
      _copyWith(featureLabels: {...featureLabels, key: newLabel});

  /// Returns a copy with features reordered per [order].
  PlanFeatureMatrix withReorderedFeatures(List<String> order) =>
      _copyWith(featureOrder: order);

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool planHasFeature(String planName, String feature) =>
      planFeatures[planName]?.contains(feature) ?? false;

  String labelFor(String key) =>
      featureLabels[key] ?? SaasFeature.labelFor(key);

  Map<String, Set<String>> _deepCopyPlanFeatures() =>
      planFeatures.map((k, v) => MapEntry(k, Set<String>.from(v)));

  PlanFeatureMatrix _copyWith({
    Map<String, Set<String>>? planFeatures,
    Map<String, String>? featureLabels,
    List<String>? featureOrder,
  }) =>
      PlanFeatureMatrix(
        planFeatures: planFeatures ?? _deepCopyPlanFeatures(),
        featureLabels: featureLabels ?? Map.from(this.featureLabels),
        featureOrder: featureOrder ?? List.from(this.featureOrder),
      );
}
