import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/sale.dart';

const _kQueueKey = 'offline_sale_queue';

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────

class PendingSale {
  final String id; // microsecondsSinceEpoch string
  final Map<String, dynamic> payload; // CheckoutPayload.toJson()
  final DateTime queuedAt;
  final int attempts;

  const PendingSale({
    required this.id,
    required this.payload,
    required this.queuedAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
        'attempts': attempts,
      };

  factory PendingSale.fromJson(Map<String, dynamic> j) => PendingSale(
        id: j['id'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        queuedAt: DateTime.parse(j['queuedAt'] as String),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );

  PendingSale copyWith({int? attempts}) => PendingSale(
        id: id,
        payload: payload,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Persistent store helpers (no state — raw SharedPreferences access)
// ─────────────────────────────────────────────────────────────────────────────

Future<List<PendingSale>> _loadRaw() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kQueueKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => PendingSale.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveRaw(List<PendingSale> queue) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _kQueueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
}

// ─────────────────────────────────────────────────────────────────────────────
//  StateNotifier — reactive queue
// ─────────────────────────────────────────────────────────────────────────────

class OfflineQueueNotifier extends StateNotifier<List<PendingSale>> {
  Completer<void>? _initCompleter;

  OfflineQueueNotifier() : super([]) {
    _initCompleter = Completer<void>();
    _reload();
  }

  Future<void> _reload() async {
    final loaded = await _loadRaw();
    state = loaded;
    _initCompleter?.complete();
  }

  /// Wait until the initial load from disk is complete.
  Future<void> ensureLoaded() async {
    if (_initCompleter?.isCompleted == false) {
      await _initCompleter!.future;
    }
  }

  /// Enqueue a checkout to be synced later.
  Future<PendingSale> enqueue(CheckoutPayload payload) async {
    await ensureLoaded();
    final entry = PendingSale(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      payload: payload.toJson(),
      queuedAt: DateTime.now(),
    );
    final queue = List<PendingSale>.from(state)..add(entry);
    await _saveRaw(queue);
    state = queue;
    return entry;
  }

  /// Remove a successfully-synced entry.
  Future<void> remove(String id) async {
    final queue = state.where((e) => e.id != id).toList();
    await _saveRaw(queue);
    state = queue;
  }

  /// Increment retry counter for a failed entry.
  Future<void> markAttempt(String id) async {
    final queue = state
        .map((e) => e.id == id ? e.copyWith(attempts: e.attempts + 1) : e)
        .toList();
    await _saveRaw(queue);
    state = queue;
  }

  /// Force a reload from disk (e.g. after app resume).
  Future<void> reload() => _reload();
}

final offlineQueueProvider =
    StateNotifierProvider<OfflineQueueNotifier, List<PendingSale>>(
  (ref) => OfflineQueueNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
//  Generic API mutation queue (inventory / customer write ops)
// ─────────────────────────────────────────────────────────────────────────────

const _kMutationQueueKey = 'offline_mutations';

/// A single API write operation to be replayed when connectivity is restored.
class PendingMutation {
  final String id; // microsecondsSinceEpoch string
  final String method; // 'POST' | 'PATCH' | 'PUT' | 'DELETE'
  final String path; // e.g. '/inventory/items/'
  final Map<String, dynamic>? body; // request body (null for DELETE)
  final String description; // human-readable: "Add item Panadol"
  final DateTime queuedAt;
  final int attempts;

  const PendingMutation({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.description,
    required this.queuedAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'description': description,
        'queuedAt': queuedAt.toIso8601String(),
        'attempts': attempts,
      };

  factory PendingMutation.fromJson(Map<String, dynamic> j) => PendingMutation(
        id: j['id'] as String,
        method: j['method'] as String,
        path: j['path'] as String,
        body: j['body'] != null
            ? Map<String, dynamic>.from(j['body'] as Map)
            : null,
        description: (j['description'] as String?) ?? '',
        queuedAt: DateTime.parse(j['queuedAt'] as String),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );

  PendingMutation copyWith({int? attempts}) => PendingMutation(
        id: id,
        method: method,
        path: path,
        body: body,
        description: description,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
      );
}

Future<List<PendingMutation>> _loadMutationsRaw() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kMutationQueueKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => PendingMutation.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveMutationsRaw(List<PendingMutation> queue) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _kMutationQueueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
}

class OfflineMutationQueueNotifier
    extends StateNotifier<List<PendingMutation>> {
  Completer<void>? _initCompleter;

  OfflineMutationQueueNotifier() : super([]) {
    _initCompleter = Completer<void>();
    _reload();
  }

  Future<void> _reload() async {
    final loaded = await _loadMutationsRaw();
    state = loaded;
    _initCompleter?.complete();
  }

  /// Wait until the initial load from disk is complete.
  Future<void> ensureLoaded() async {
    if (_initCompleter?.isCompleted == false) {
      await _initCompleter!.future;
    }
  }

  Future<PendingMutation> enqueue(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String description = '',
  }) async {
    await ensureLoaded();

    // ── Deduplication rules ─────────────────────────────────────────────────
    // PATCH / PUT on the same path: replace the body of the existing queued
    // mutation instead of appending. This means the latest local edit wins and
    // sync applies it exactly once rather than twice.
    if (method == 'PATCH' || method == 'PUT') {
      final existingIndex =
          state.indexWhere((m) => m.method == method && m.path == path);
      if (existingIndex >= 0) {
        final existing = state[existingIndex];
        final updated = PendingMutation(
          id: existing.id, // keep original id (idempotency anchor)
          method: existing.method,
          path: existing.path,
          body: body,
          description: description.isNotEmpty ? description : existing.description,
          queuedAt: existing.queuedAt,
          attempts: existing.attempts,
        );
        final queue = List<PendingMutation>.from(state);
        queue[existingIndex] = updated;
        await _saveMutationsRaw(queue);
        state = queue;
        return updated;
      }
    }

    // DELETE on the same path: skip if already queued — deleting twice is a no-op.
    if (method == 'DELETE') {
      final existing = state.firstWhere(
        (m) => m.method == 'DELETE' && m.path == path,
        orElse: () => PendingMutation(
          id: '',
          method: '',
          path: '',
          description: '',
          queuedAt: DateTime.now(),
        ),
      );
      if (existing.id.isNotEmpty) return existing;
    }
    // ────────────────────────────────────────────────────────────────────────

    final entry = PendingMutation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      path: path,
      body: body,
      description: description,
      queuedAt: DateTime.now(),
    );
    final queue = List<PendingMutation>.from(state)..add(entry);
    await _saveMutationsRaw(queue);
    state = queue;
    return entry;
  }

  Future<void> remove(String id) async {
    final queue = state.where((e) => e.id != id).toList();
    await _saveMutationsRaw(queue);
    state = queue;
  }

  Future<void> markAttempt(String id) async {
    final queue = state
        .map((e) => e.id == id ? e.copyWith(attempts: e.attempts + 1) : e)
        .toList();
    await _saveMutationsRaw(queue);
    state = queue;
  }

  Future<void> reload() => _reload();
}

final offlineMutationQueueProvider =
    StateNotifierProvider<OfflineMutationQueueNotifier, List<PendingMutation>>(
  (ref) => OfflineMutationQueueNotifier(),
);
