import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/drug_interaction_service.dart';
import '../../../core/services/rxnorm_service.dart';
import '../../customers/providers/customer_provider.dart';
import 'cart_provider.dart';

export '../../../core/services/rxnorm_service.dart' show RxNormInteraction;

// ── Unified warning model for POS ─────────────────────────────────────────────

class PosWarning {
  final String title;
  final String description;
  final String severity; // 'allergy' | 'major' | 'high' | 'moderate' | 'low' | 'minor' | 'unknown'
  final String source;   // 'Patient Profile' | 'RxNorm: DrugBank' | etc.

  const PosWarning({
    required this.title,
    required this.description,
    required this.severity,
    required this.source,
  });
}

// ── Internal helpers ──────────────────────────────────────────────────────────

String _warningSeverityToString(WarningSeverity s) {
  switch (s) {
    case WarningSeverity.allergy:  return 'allergy';
    case WarningSeverity.major:    return 'major';
    case WarningSeverity.moderate: return 'moderate';
    case WarningSeverity.minor:    return 'minor';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final rxNormServiceProvider = Provider<RxNormService>((_) => RxNormService());

// Unique sorted drug names in cart — only changes when drugs are added/removed,
// not when quantities change, so RxNorm is not re-queried on every qty update.
final _cartDrugNamesProvider = Provider<List<String>>((ref) {
  final cart = ref.watch(cartProvider);
  return (cart.map((c) => c.item.name).toSet().toList()..sort());
});

// RxNorm drug-drug interactions (online only — silently returns [] when offline/unreachable)
final drugInteractionsProvider = FutureProvider<List<RxNormInteraction>>((ref) async {
  final names = ref.watch(_cartDrugNamesProvider);
  if (names.length < 2) return [];
  return ref.read(rxNormServiceProvider).checkInteractions(names);
});

// Patient-specific warnings: allergy + medication interaction checks (offline-capable)
final patientWarningsProvider = FutureProvider<List<PosWarning>>((ref) async {
  final cart    = ref.watch(cartProvider);
  final patient = ref.watch(selectedCustomerProvider);
  if (cart.isEmpty || patient == null) return [];

  try {
    final detail = await ref.read(customerDetailProvider(patient.id).future);
    if (detail.allergies.isEmpty && detail.currentMedications.isEmpty) return [];

    final warnings = <PosWarning>[];
    for (final cartItem in cart) {
      final drugWarnings = DrugInteractionService.checkInteractions(
        cartItem.item.name,
        detail.currentMedications,
        detail.allergies,
      );
      for (final w in drugWarnings) {
        warnings.add(PosWarning(
          title: cartItem.item.name,
          description: w.message,
          severity: _warningSeverityToString(w.severity),
          source: 'Patient Profile',
        ));
      }
    }
    return warnings;
  } catch (_) {
    return [];
  }
});

// Combined: patient profile warnings first (higher priority), then RxNorm
final combinedPosWarningsProvider = FutureProvider<List<PosWarning>>((ref) async {
  final patient = await ref.watch(patientWarningsProvider.future);
  final rxnorm  = await ref.watch(drugInteractionsProvider.future);

  final rxnormMapped = rxnorm.map((i) => PosWarning(
    title: '${i.drug1} + ${i.drug2}',
    description: i.description,
    severity: i.severity,
    source: i.source.isNotEmpty ? 'RxNorm: ${i.source}' : 'RxNorm',
  )).toList();

  return [...patient, ...rxnormMapped];
});
