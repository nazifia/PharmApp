import 'package:isar/isar.dart';
import 'dart:convert';
import 'sale.dart';

part 'checkout_queue_entity.g.dart';

@collection
class CheckoutQueueEntity {
  Id id = Isar.autoIncrement;

  late DateTime createdAt;

  /// The full checkout payload serialised as JSON for offline caching.
  late String payloadJson;

  /// Tracks whether this record has been synced to the server.
  bool isSynced = false;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Deserialises the stored JSON back to a [CheckoutPayload].
  /// Defined as a regular method (not a getter) so Isar does not try
  /// to analyse its return type.
  CheckoutPayload decodePayload() =>
      CheckoutPayload.fromJson(jsonDecode(payloadJson) as Map<String, dynamic>);

  static CheckoutQueueEntity fromPayload(CheckoutPayload payload) {
    return CheckoutQueueEntity()
      ..createdAt  = DateTime.now()
      ..payloadJson = jsonEncode(payload.toJson())
      ..isSynced   = false;
  }
}
