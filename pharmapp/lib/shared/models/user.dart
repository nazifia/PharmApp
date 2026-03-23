import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required int id,
    required String phoneNumber,
    required String role, // e.g., 'Admin', 'Pharmacist', 'Cashier'
    required bool isActive,
    @Default('') String username,
    @Default(false) bool isWholesaleOperator,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
