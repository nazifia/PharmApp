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
    @Default('') String fullname,
    @Default(false) bool isWholesaleOperator,
    @Default(false) bool isSuperuser,
    @Default(0) int organizationId,
    @Default('') String organizationName,
    @Default('') String organizationSlug,
    @Default('') String organizationAddress,
    @Default('') String organizationPhone,
    @Default('') String organizationLogo,
    @Default(0) int branchId,
    @Default('') String branchName,
    @Default(<String, bool>{}) Map<String, bool> permissions,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
