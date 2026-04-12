import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/branch.dart';

// ── API client ────────────────────────────────────────────────────────────────

class BranchApiClient {
  final Dio _dio;
  BranchApiClient(this._dio);

  Future<List<Branch>> list() async {
    final res = await _dio.get('/branches/');
    return (res.data as List<dynamic>)
        .map((e) => Branch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Branch> create({
    required String name,
    String address = '',
    String phone   = '',
    String email   = '',
  }) async {
    final res = await _dio.post('/branches/create/', data: {
      'name':    name,
      'address': address,
      'phone':   phone,
      'email':   email,
    });
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Branch> update(
    int id, {
    String? name,
    String? address,
    String? phone,
    String? email,
  }) async {
    final body = <String, dynamic>{};
    if (name    != null) body['name']    = name;
    if (address != null) body['address'] = address;
    if (phone   != null) body['phone']   = phone;
    if (email   != null) body['email']   = email;

    final res = await _dio.patch('/branches/$id/update/', data: body);
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deactivate(int id) async {
    await _dio.delete('/branches/$id/delete/');
  }

  Future<Branch> setMain(int id) async {
    final res = await _dio.post('/branches/$id/set-main/');
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }
}

final branchApiClientProvider = Provider<BranchApiClient>(
  (ref) => BranchApiClient(ref.watch(dioProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────────

class BranchNotifier extends StateNotifier<AsyncValue<List<Branch>>> {
  final Ref _ref;

  BranchNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final branches = await _ref.read(branchApiClientProvider).list();
      state = AsyncValue.data(branches);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> create({
    required String name,
    String address = '',
    String phone   = '',
    String email   = '',
  }) async {
    try {
      await _ref.read(branchApiClientProvider).create(
        name: name, address: address, phone: phone, email: email,
      );
      await load();
      return null;
    } on DioException catch (e) {
      return (e.response?.data as Map?)?['detail'] as String? ?? 'Failed to create branch.';
    } catch (_) {
      return 'Failed to create branch.';
    }
  }

  Future<String?> update(
    int id, {
    String? name,
    String? address,
    String? phone,
    String? email,
  }) async {
    try {
      await _ref.read(branchApiClientProvider).update(
        id, name: name, address: address, phone: phone, email: email,
      );
      await load();
      return null;
    } on DioException catch (e) {
      return (e.response?.data as Map?)?['detail'] as String? ?? 'Failed to update branch.';
    } catch (_) {
      return 'Failed to update branch.';
    }
  }

  Future<String?> deactivate(int id) async {
    try {
      await _ref.read(branchApiClientProvider).deactivate(id);
      await load();
      return null;
    } on DioException catch (e) {
      return (e.response?.data as Map?)?['detail'] as String? ?? 'Failed to deactivate branch.';
    } catch (_) {
      return 'Failed to deactivate branch.';
    }
  }

  Future<String?> setMain(int id) async {
    try {
      await _ref.read(branchApiClientProvider).setMain(id);
      await load();
      return null;
    } catch (_) {
      return 'Failed to set main branch.';
    }
  }
}

final branchNotifierProvider =
    StateNotifierProvider<BranchNotifier, AsyncValue<List<Branch>>>(
  (ref) => BranchNotifier(ref),
);

/// Convenience: resolved list (empty while loading).
final branchListProvider = Provider<List<Branch>>((ref) {
  return ref.watch(branchNotifierProvider).valueOrNull ?? [];
});

/// The currently active branch the user is working in.
/// Null = all branches / not yet selected.
final activeBranchProvider = StateProvider<Branch?>((ref) => null);
