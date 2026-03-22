import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/sale.dart';

const _kQueueKey = 'offline_sale_queue';

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────

class PendingSale {
  final String id;                      // microsecondsSinceEpoch string
  final Map<String, dynamic> payload;   // CheckoutPayload.toJson()
  final DateTime queuedAt;
  final int attempts;

  const PendingSale({
    required this.id,
    required this.payload,
    required this.queuedAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
    'id':       id,
    'payload':  payload,
    'queuedAt': queuedAt.toIso8601String(),
    'attempts': attempts,
  };

  factory PendingSale.fromJson(Map<String, dynamic> j) => PendingSale(
    id:       j['id'] as String,
    payload:  Map<String, dynamic>.from(j['payload'] as Map),
    queuedAt: DateTime.parse(j['queuedAt'] as String),
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
  );

  PendingSale copyWith({int? attempts}) => PendingSale(
    id: id, payload: payload, queuedAt: queuedAt,
    attempts: attempts ?? this.attempts,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Persistent store helpers (no state — raw SharedPreferences access)
// ─────────────────────────────────────────────────────────────────────────────

Future<List<PendingSale>> _loadRaw() async {
  final prefs = await SharedPreferences.getInstance();
  final raw   = prefs.getString(_kQueueKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list.map((e) => PendingSale.fromJson(e as Map<String, dynamic>)).toList();
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
  OfflineQueueNotifier() : super([]) {
    _reload();
  }

  Future<void> _reload() async {
    state = await _loadRaw();
  }

  /// Enqueue a checkout to be synced later.
  Future<PendingSale> enqueue(CheckoutPayload payload) async {
    final entry = PendingSale(
      id:       DateTime.now().microsecondsSinceEpoch.toString(),
      payload:  payload.toJson(),
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
    final queue = state.map((e) => e.id == id ? e.copyWith(attempts: e.attempts + 1) : e).toList();
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
