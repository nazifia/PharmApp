import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Drug availability across network pharmacies ───────────────────────────────

class DrugAvailability {
  final String pharmacyName;
  final int pharmacyId;
  final int stockQuantity;
  final String? address;
  final String? phone;
  final String? distance; // e.g. "1.2 km" — optional field from backend

  const DrugAvailability({
    required this.pharmacyName,
    required this.pharmacyId,
    required this.stockQuantity,
    this.address,
    this.phone,
    this.distance,
  });

  factory DrugAvailability.fromJson(Map<String, dynamic> j) => DrugAvailability(
        pharmacyName:  (j['pharmacy_name']  ?? j['pharmacyName']  as String?) ?? '',
        pharmacyId:    ((j['pharmacy_id']   ?? j['pharmacyId'])   as num?)?.toInt() ?? 0,
        stockQuantity: ((j['stock_quantity']?? j['stockQuantity']) as num?)?.toInt() ?? 0,
        address:       j['address']  as String?,
        phone:         j['phone']    as String?,
        distance:      j['distance'] as String?,
      );
}

// ── Models ────────────────────────────────────────────────────────────────────

class PharmacyNetwork {
  final int id;
  final String name;
  final String slug;
  final String description;
  final bool isActive;
  final String createdAt;
  final int memberCount;
  final String? myRole;   // 'owner' | 'member' — null when fetched as member list
  final String? myStatus; // 'active' | 'pending' | 'suspended'
  final List<NetworkMembership> members;

  const PharmacyNetwork({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.memberCount,
    this.myRole,
    this.myStatus,
    this.members = const [],
  });

  factory PharmacyNetwork.fromJson(Map<String, dynamic> j) => PharmacyNetwork(
        id:          (j['id'] as num).toInt(),
        name:        j['name'] as String,
        slug:        j['slug'] as String,
        description: (j['description'] as String?) ?? '',
        isActive:    (j['isActive'] as bool?) ?? true,
        createdAt:   j['createdAt'] as String,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        myRole:      j['myRole'] as String?,
        myStatus:    j['myStatus'] as String?,
        members:     (j['members'] as List? ?? [])
            .map((e) => NetworkMembership.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class NetworkMembership {
  final int id;
  final int networkId;
  final String networkName;
  final String networkSlug;
  final int organizationId;
  final String organizationName;
  final String organizationSlug;
  final String role;
  final String status;
  final String? joinedAt;

  const NetworkMembership({
    required this.id,
    required this.networkId,
    required this.networkName,
    required this.networkSlug,
    required this.organizationId,
    required this.organizationName,
    required this.organizationSlug,
    required this.role,
    required this.status,
    this.joinedAt,
  });

  factory NetworkMembership.fromJson(Map<String, dynamic> j) => NetworkMembership(
        id:               (j['id'] as num).toInt(),
        networkId:        (j['networkId'] as num).toInt(),
        networkName:      j['networkName'] as String,
        networkSlug:      j['networkSlug'] as String,
        organizationId:   (j['organizationId'] as num).toInt(),
        organizationName: j['organizationName'] as String,
        organizationSlug: j['organizationSlug'] as String,
        role:             j['role'] as String,
        status:           j['status'] as String,
        joinedAt:         j['joinedAt'] as String?,
      );

  bool get isActive  => status == 'active';
  bool get isPending => status == 'pending';
  bool get isOwner   => role == 'owner';
}

// ── API client ────────────────────────────────────────────────────────────────

class NetworkApiClient {
  final Dio _dio;
  const NetworkApiClient(this._dio);

  Future<List<NetworkMembership>> fetchMyNetworks() async {
    final res = await _dio.get('/auth/networks/');
    final list = res.data as List;
    return list.map((e) => NetworkMembership.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PharmacyNetwork> fetchNetwork(int id) async {
    final res = await _dio.get('/auth/networks/$id/');
    return PharmacyNetwork.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PharmacyNetwork> createNetwork({
    required String name,
    String description = '',
  }) async {
    final res = await _dio.post('/auth/networks/', data: {
      'name': name,
      if (description.isNotEmpty) 'description': description,
    });
    return PharmacyNetwork.fromJson(res.data as Map<String, dynamic>);
  }

  Future<NetworkMembership> inviteOrg(int networkId, String orgSlug) async {
    final res = await _dio.post('/auth/networks/$networkId/invite/', data: {
      'org_slug': orgSlug,
    });
    return NetworkMembership.fromJson(res.data as Map<String, dynamic>);
  }

  Future<NetworkMembership> acceptInvitation(int networkId) async {
    final res = await _dio.post('/auth/networks/$networkId/accept/');
    return NetworkMembership.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> declineInvitation(int networkId) async {
    await _dio.post('/auth/networks/$networkId/decline/');
  }

  Future<void> leaveNetwork(int networkId) async {
    await _dio.delete('/auth/networks/$networkId/leave/');
  }

  Future<void> removeMember(int networkId, int orgId) async {
    await _dio.delete('/auth/networks/$networkId/members/$orgId/');
  }

  /// Called after org registration — silently joins the platform default network.
  /// Errors are swallowed so a missing/unavailable endpoint never breaks sign-up.
  Future<void> joinDefaultNetwork() async {
    try {
      await _dio.post('/auth/networks/join-default/');
    } catch (_) {}
  }

  /// Returns which pharmacies in the shared network carry [drugName] and their
  /// current stock levels.
  Future<List<DrugAvailability>> fetchDrugAvailability(
      String drugName) async {
    try {
      final res = await _dio.get(
        '/inventory/availability/',
        queryParameters: {'name': drugName},
      );
      final data = res.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : data as List;
      return list
          .map((e) => DrugAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'You are offline. Cannot check network availability.');
      }
      throw Exception(
          e.response?.data?['detail'] ?? 'Failed to check medication availability');
    }
  }
}

final networkApiProvider = Provider<NetworkApiClient>((ref) {
  return NetworkApiClient(ref.watch(dioProvider));
});

// ── Providers ─────────────────────────────────────────────────────────────────

/// All networks the current org belongs to (any status).
final myNetworksProvider = FutureProvider.autoDispose<List<NetworkMembership>>((ref) {
  return ref.watch(networkApiProvider).fetchMyNetworks();
});

/// Active network memberships only.
final activeNetworksProvider = FutureProvider.autoDispose<List<NetworkMembership>>((ref) async {
  final all = await ref.watch(myNetworksProvider.future);
  return all.where((m) => m.isActive).toList();
});

/// Pending invitations for the current org.
final pendingNetworkInvitesProvider = FutureProvider.autoDispose<List<NetworkMembership>>((ref) async {
  final all = await ref.watch(myNetworksProvider.future);
  return all.where((m) => m.isPending).toList();
});

final networkDetailProvider =
    FutureProvider.autoDispose.family<PharmacyNetwork, int>((ref, id) {
  return ref.watch(networkApiProvider).fetchNetwork(id);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class NetworkNotifier extends StateNotifier<AsyncValue<void>> {
  final NetworkApiClient _api;
  final Ref _ref;

  NetworkNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<PharmacyNetwork?> createNetwork(String name, {String description = ''}) async {
    state = const AsyncValue.loading();
    try {
      final network = await _api.createNetwork(name: name, description: description);
      _ref.invalidate(myNetworksProvider);
      state = const AsyncValue.data(null);
      return network;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<NetworkMembership?> inviteOrg(int networkId, String orgSlug) async {
    state = const AsyncValue.loading();
    try {
      final m = await _api.inviteOrg(networkId, orgSlug);
      _ref.invalidate(networkDetailProvider(networkId));
      state = const AsyncValue.data(null);
      return m;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> acceptInvitation(int networkId) async {
    state = const AsyncValue.loading();
    try {
      await _api.acceptInvitation(networkId);
      _ref.invalidate(myNetworksProvider);
      _ref.invalidate(networkDetailProvider(networkId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> declineInvitation(int networkId) async {
    state = const AsyncValue.loading();
    try {
      await _api.declineInvitation(networkId);
      _ref.invalidate(myNetworksProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> leaveNetwork(int networkId) async {
    state = const AsyncValue.loading();
    try {
      await _api.leaveNetwork(networkId);
      _ref.invalidate(myNetworksProvider);
      _ref.invalidate(networkDetailProvider(networkId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeMember(int networkId, int orgId) async {
    state = const AsyncValue.loading();
    try {
      await _api.removeMember(networkId, orgId);
      _ref.invalidate(networkDetailProvider(networkId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final networkNotifierProvider =
    StateNotifierProvider<NetworkNotifier, AsyncValue<void>>((ref) {
  return NetworkNotifier(ref.watch(networkApiProvider), ref);
});

// ── Medication availability provider ──────────────────────────────────────────

/// Fetches stock levels for [drugName] across all pharmacies in the shared
/// network.  Results are keyed by drug name string so each lookup is cached
/// independently.
final drugAvailabilityProvider =
    FutureProvider.autoDispose.family<List<DrugAvailability>, String>(
        (ref, drugName) {
  return ref.watch(networkApiProvider).fetchDrugAvailability(drugName);
});
