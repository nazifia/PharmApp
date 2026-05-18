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
    if (dio == null) return const [];

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
}

// ── Provider ──────────────────────────────────────────────────────────────────

final activityLogProvider =
    StateNotifierProvider.autoDispose<ActivityLogNotifier, ActivityLogState>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return ActivityLogNotifier(null);
  return ActivityLogNotifier(ref.watch(dioProvider));
});
