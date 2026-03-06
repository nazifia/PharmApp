import 'package:isar/isar.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:convert';
import 'sale.dart';

part 'checkout_queue_entity.g.dart';

@collection
class CheckoutQueueEntity {
  Id id = Isar.autoIncrement;

  late DateTime createdAt;
  
  // Storing the JSON payload string directly since it's an offline cache
  late String payloadJson;
  
  // Track sync status to avoid duplicate submissions
  bool isSynced = false;

  // Conversion helpers
  @ignore
  CheckoutPayload get payload => CheckoutPayload.fromJson(jsonDecode(payloadJson));

  static CheckoutQueueEntity fromPayload(CheckoutPayload payload) {
    return CheckoutQueueEntity()
      ..createdAt = DateTime.now()
      ..payloadJson = jsonEncode(payload.toJson())
      ..isSynced = false;
  }
}
