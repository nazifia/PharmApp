import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/commission_config.dart';
import 'reports_provider.dart';

final commissionConfigsProvider = FutureProvider<List<CommissionConfig>>((ref) {
  return ref.watch(reportsApiProvider).fetchCommissionConfigs();
});

final staffPerformanceProvider =
    FutureProvider.family<StaffPerformanceData, String>((ref, period) {
  return ref.watch(reportsApiProvider).fetchStaffPerformance(period);
});

class CommissionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  CommissionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateRate(int userId, double rate, double? bonus) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(reportsApiProvider).updateCommissionConfig(userId, rate, bonus);
      _ref.invalidate(commissionConfigsProvider);
      _ref.invalidate(staffPerformanceProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final commissionNotifierProvider =
    StateNotifierProvider<CommissionNotifier, AsyncValue<void>>(
        (ref) => CommissionNotifier(ref));
