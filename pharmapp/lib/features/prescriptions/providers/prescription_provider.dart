import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../features/branches/providers/branch_provider.dart';
import '../../../shared/models/customer.dart';
import '../../../shared/models/prescription.dart';
import 'prescription_api_client.dart';

// ── API client provider ───────────────────────────────────────────────────────

final prescriptionApiProvider = Provider<PrescriptionApiClient>((ref) {
  return PrescriptionApiClient(ref.watch(dioProvider));
});

// ── Filter params ─────────────────────────────────────────────────────────────

class PrescriptionFilter {
  final String? status; // 'pending' | 'partial' | 'dispensed' | null = all
  final String? search;

  const PrescriptionFilter({this.status, this.search});

  @override
  bool operator ==(Object other) =>
      other is PrescriptionFilter &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

// ── List provider ─────────────────────────────────────────────────────────────

final prescriptionListProvider =
    FutureProvider.autoDispose.family<List<Prescription>, PrescriptionFilter>(
        (ref, filter) {
  final branch = ref.watch(activeBranchProvider);
  final branchId = (branch == null || branch.id <= 0) ? null : branch.id;
  return ref.watch(prescriptionApiProvider).fetchPrescriptions(
        status: filter.status,
        search: filter.search,
        branchId: branchId,
      );
});

/// Convenience provider — prescriptions with any undispensed medications
/// (status = pending OR partial).
final undispensedPrescriptionsProvider =
    FutureProvider.autoDispose<List<Prescription>>((ref) {
  final branch = ref.watch(activeBranchProvider);
  final branchId = (branch == null || branch.id <= 0) ? null : branch.id;
  return ref
      .watch(prescriptionApiProvider)
      .fetchPrescriptions(status: 'undispensed', branchId: branchId);
});

// ── Single prescription ───────────────────────────────────────────────────────

final prescriptionDetailProvider =
    FutureProvider.autoDispose.family<Prescription, int>((ref, id) {
  return ref.watch(prescriptionApiProvider).fetchPrescription(id);
});

// ── Create / dispense notifier ────────────────────────────────────────────────

class PrescriptionNotifier extends StateNotifier<AsyncValue<void>> {
  final PrescriptionApiClient _api;
  final Ref _ref;

  PrescriptionNotifier(this._api, this._ref)
      : super(const AsyncValue.data(null));

  Future<Prescription?> createPrescription(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final prescription = await _api.createPrescription(data);
      _invalidateLists();
      state = const AsyncValue.data(null);
      return prescription;
    } on DioException catch (e, st) {
      if (e.response == null) {
        // Queue for offline sync
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
              'POST',
              '/prescriptions/',
              body: data,
              description:
                  'Create prescription for ${data['customer_name'] ?? 'patient'}',
            );
        _invalidateLists();
        state = const AsyncValue.data(null);
        return null; // null = queued offline
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Prescription?> update(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _api.updatePrescription(id, data);
      _ref.invalidate(prescriptionDetailProvider(id));
      _invalidateLists();
      state = const AsyncValue.data(null);
      return updated;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
              'PATCH',
              '/prescriptions/$id/',
              body: data,
              description: 'Update prescription #$id',
            );
        _ref.invalidate(prescriptionDetailProvider(id));
        _invalidateLists();
        state = const AsyncValue.data(null);
        return null;
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Prescription?> dispense(int id, {List<int>? itemIndices}) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _api.dispensePrescription(id, itemIndices: itemIndices);
      // Only invalidate lists — the detail screen manages its own state via
      // _localRx so the optimistic/PATCH result stays visible without a reload.
      _invalidateLists();
      state = const AsyncValue.data(null);
      return updated;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
              'PATCH',
              '/prescriptions/$id/dispense/',
              body: itemIndices != null ? {'item_indices': itemIndices} : {},
              description: 'Dispense prescription #$id',
            );
        state = const AsyncValue.data(null);
        return null;
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void _invalidateLists() {
    _ref.invalidate(prescriptionListProvider);
    _ref.invalidate(undispensedPrescriptionsProvider);
  }
}

final prescriptionNotifierProvider =
    StateNotifierProvider<PrescriptionNotifier, AsyncValue<void>>((ref) {
  return PrescriptionNotifier(ref.watch(prescriptionApiProvider), ref);
});

// ── Per-customer prescription providers ──────────────────────────────────────

class CustomerPrescriptionFilter {
  final int customerId;
  final bool undispensedOnly;
  const CustomerPrescriptionFilter(this.customerId,
      {this.undispensedOnly = false});

  @override
  bool operator ==(Object other) =>
      other is CustomerPrescriptionFilter &&
      other.customerId == customerId &&
      other.undispensedOnly == undispensedOnly;

  @override
  int get hashCode => Object.hash(customerId, undispensedOnly);
}

/// Prescriptions belonging to a specific customer (by ID).
final customerPrescriptionsProvider = FutureProvider.autoDispose
    .family<List<Prescription>, CustomerPrescriptionFilter>((ref, filter) {
  return ref
      .watch(prescriptionApiProvider)
      .fetchCustomerPrescriptions(filter.customerId,
          undispensedOnly: filter.undispensedOnly);
});

/// Prescriptions looked up by phone number (walk-in POS dispensing).
class PhonePrescriptionFilter {
  final String phone;
  final bool undispensedOnly;
  const PhonePrescriptionFilter(this.phone, {this.undispensedOnly = false});

  @override
  bool operator ==(Object other) =>
      other is PhonePrescriptionFilter &&
      other.phone == phone &&
      other.undispensedOnly == undispensedOnly;

  @override
  int get hashCode => Object.hash(phone, undispensedOnly);
}

final prescriptionsByPhoneProvider = FutureProvider.autoDispose
    .family<List<Prescription>, PhonePrescriptionFilter>((ref, filter) {
  if (filter.phone.trim().isEmpty) return Future.value([]);
  return ref
      .watch(prescriptionApiProvider)
      .fetchPrescriptionsByPhone(filter.phone,
          undispensedOnly: filter.undispensedOnly);
});

// ── Global customer search ────────────────────────────────────────────────────

/// Search customers across all subscribed pharmacies by phone or name.
/// Returns raw maps with an extra 'pharmacyName' field.
class GlobalCustomerSearchResult {
  final int? id;
  final String name;
  final String phone;
  final bool isWholesale;
  final String? pharmacyName;
  final int? pharmacyId;

  const GlobalCustomerSearchResult({
    this.id,
    required this.name,
    required this.phone,
    this.isWholesale = false,
    this.pharmacyName,
    this.pharmacyId,
  });

  factory GlobalCustomerSearchResult.fromJson(Map<String, dynamic> j) =>
      GlobalCustomerSearchResult(
        id: j['id'] as int?,
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] ?? j['phoneNumber'] as String?) ?? '',
        isWholesale: (j['is_wholesale'] ?? j['isWholesale'] as bool?) ?? false,
        pharmacyName:
            (j['pharmacy_name'] ?? j['pharmacyName']) as String?,
        pharmacyId: (j['pharmacy_id'] ?? j['pharmacyId']) as int?,
      );

  Customer toCustomer() => Customer(
        id: id ?? 0,
        name: name,
        phone: phone,
        isWholesale: isWholesale,
        walletBalance: 0,
        totalPurchases: 0,
        outstandingDebt: 0,
      );
}

// ── Medication availability across pharmacies ─────────────────────────────────

class MedicationAvailabilityQuery {
  final String name;
  final String? brand;
  const MedicationAvailabilityQuery({required this.name, this.brand});

  @override
  bool operator ==(Object other) =>
      other is MedicationAvailabilityQuery &&
      other.name == name &&
      other.brand == brand;

  @override
  int get hashCode => Object.hash(name, brand);
}

final medicationAvailabilityProvider = FutureProvider.autoDispose
    .family<List<MedicationAvailability>, MedicationAvailabilityQuery>(
        (ref, query) {
  return ref
      .watch(prescriptionApiProvider)
      .fetchMedicationAvailability(query.name, brand: query.brand);
});

final globalCustomerSearchProvider = FutureProvider.autoDispose
    .family<List<GlobalCustomerSearchResult>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  try {
    final api = ref.watch(prescriptionApiProvider);
    final results = await api.searchCustomersGlobal(query.trim());
    return results
        .map((e) => GlobalCustomerSearchResult.fromJson(e))
        .toList();
  } on DioException catch (e) {
    if (e.response == null) {
      // Offline: fall back to local customer cache
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cache_customers');
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final q = query.toLowerCase();
      return list
          .cast<Map<String, dynamic>>()
          .where((m) =>
              (m['name'] as String? ?? '').toLowerCase().contains(q) ||
              (m['phone'] as String? ?? '').contains(q))
          .map((m) => GlobalCustomerSearchResult(
                id: m['id'] as int?,
                name: (m['name'] as String?) ?? '',
                phone: (m['phone'] as String?) ?? '',
              ))
          .toList();
    }
    rethrow;
  }
});
