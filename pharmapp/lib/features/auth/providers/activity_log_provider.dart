import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/activity_log.dart';

// ── Filter params ─────────────────────────────────────────────────────────────

class ActivityLogFilter {
  final String category; // 'all' or specific category
  final String search;
  final int page;

  const ActivityLogFilter({
    this.category = 'all',
    this.search = '',
    this.page = 1,
  });

  ActivityLogFilter copyWith({String? category, String? search, int? page}) {
    return ActivityLogFilter(
      category: category ?? this.category,
      search: search ?? this.search,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ActivityLogFilter &&
      other.category == category &&
      other.search == search &&
      other.page == page;

  @override
  int get hashCode => Object.hash(category, search, page);
}

// ── State ─────────────────────────────────────────────────────────────────────

class ActivityLogState {
  final List<ActivityLog> logs;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final ActivityLogFilter filter;

  const ActivityLogState({
    this.logs = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.filter = const ActivityLogFilter(),
  });

  ActivityLogState copyWith({
    List<ActivityLog>? logs,
    bool? isLoading,
    bool? hasMore,
    String? error,
    ActivityLogFilter? filter,
  }) {
    return ActivityLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      filter: filter ?? this.filter,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ActivityLogNotifier extends StateNotifier<ActivityLogState> {
  final Dio? _dio;

  ActivityLogNotifier(this._dio) : super(const ActivityLogState()) {
    fetch();
  }

  Future<void> fetch({bool reset = true}) async {
    if (state.isLoading) return;

    final filter = reset ? state.filter.copyWith(page: 1) : state.filter;
    final logs = reset ? <ActivityLog>[] : List<ActivityLog>.from(state.logs);

    state = state.copyWith(isLoading: true, error: null, filter: filter);

    try {
      final fetched = await _fetchPage(filter);
      state = state.copyWith(
        logs: [...logs, ...fetched],
        isLoading: false,
        hasMore: fetched.length >= 30,
        filter: filter,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    final nextFilter = state.filter.copyWith(page: state.filter.page + 1);
    state = state.copyWith(filter: nextFilter);
    await fetch(reset: false);
  }

  void setCategory(String category) {
    state = state.copyWith(filter: state.filter.copyWith(category: category, page: 1));
    fetch();
  }

  void setSearch(String search) {
    state = state.copyWith(filter: state.filter.copyWith(search: search, page: 1));
    fetch();
  }

  Future<List<ActivityLog>> _fetchPage(ActivityLogFilter filter) async {
    final dio = _dio;
    if (dio == null) return _mockLogs(filter);

    final params = <String, dynamic>{
      'page': filter.page,
      'page_size': 30,
      if (filter.category != 'all') 'category': filter.category,
      if (filter.search.isNotEmpty) 'search': filter.search,
    };

    try {
      final res = await dio.get('/auth/activity-log/', queryParameters: params);
      final data = res.data;
      List<dynamic> results;
      if (data is Map) {
        results = (data['results'] ?? data['logs'] ?? []) as List<dynamic>;
      } else if (data is List) {
        results = data;
      } else {
        results = [];
      }
      return results
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) throw Exception(body['detail'] ?? 'Failed to load activity log');
      throw Exception('Network error — check server connection');
    }
  }

  List<ActivityLog> _mockLogs(ActivityLogFilter filter) {
    final now = DateTime.now();
    final all = [
      ActivityLog(id: 1, userId: 1, username: 'admin', role: 'Admin', action: 'Login', category: 'auth', description: 'Successful login from web', timestamp: now.subtract(const Duration(minutes: 5))),
      ActivityLog(id: 2, userId: 2, username: 'john_cashier', role: 'Cashier', action: 'Sale', category: 'sales', description: 'Retail checkout — ₦4,200 (3 items)', timestamp: now.subtract(const Duration(minutes: 12))),
      ActivityLog(id: 3, userId: 1, username: 'admin', role: 'Admin', action: 'Add Item', category: 'inventory', description: 'Added "Paracetamol 500mg" to inventory', timestamp: now.subtract(const Duration(minutes: 30))),
      ActivityLog(id: 4, userId: 3, username: 'mgr_sara', role: 'Manager', action: 'Create Customer', category: 'customers', description: 'New customer "Emeka Okafor" registered', timestamp: now.subtract(const Duration(hours: 1))),
      ActivityLog(id: 5, userId: 1, username: 'admin', role: 'Admin', action: 'Create User', category: 'users', description: 'New user "john_cashier" created with role Cashier', timestamp: now.subtract(const Duration(hours: 2))),
      ActivityLog(id: 6, userId: 3, username: 'mgr_sara', role: 'Manager', action: 'Adjust Stock', category: 'inventory', description: 'Stock adjusted for "Amoxicillin 250mg" (+50 units)', timestamp: now.subtract(const Duration(hours: 3))),
      ActivityLog(id: 7, userId: 2, username: 'john_cashier', role: 'Cashier', action: 'Logout', category: 'auth', description: 'User signed out', timestamp: now.subtract(const Duration(hours: 4))),
      ActivityLog(id: 8, userId: 1, username: 'admin', role: 'Admin', action: 'View Report', category: 'reports', description: 'Accessed Sales Report — period: today', timestamp: now.subtract(const Duration(hours: 5))),
      ActivityLog(id: 9, userId: 3, username: 'mgr_sara', role: 'Manager', action: 'Update Settings', category: 'settings', description: 'Changed tax rate to 7.5%', timestamp: now.subtract(const Duration(hours: 6))),
      ActivityLog(id: 10, userId: 4, username: 'pharmacist_ade', role: 'Pharmacist', action: 'Sale', category: 'sales', description: 'Retail checkout — ₦11,500 (6 items)', timestamp: now.subtract(const Duration(hours: 7))),
    ];

    var filtered = all;
    if (filter.category != 'all') {
      filtered = filtered.where((l) => l.category == filter.category).toList();
    }
    if (filter.search.isNotEmpty) {
      final q = filter.search.toLowerCase();
      filtered = filtered
          .where((l) =>
              l.username.toLowerCase().contains(q) ||
              l.action.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q))
          .toList();
    }
    return filter.page == 1 ? filtered : [];
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final activityLogProvider =
    StateNotifierProvider.autoDispose<ActivityLogNotifier, ActivityLogState>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return ActivityLogNotifier(null);
  return ActivityLogNotifier(ref.watch(dioProvider));
});
