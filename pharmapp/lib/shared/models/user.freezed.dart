// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  int get id => throw _privateConstructorUsedError;
  String get phoneNumber => throw _privateConstructorUsedError;
  String get role =>
      throw _privateConstructorUsedError; // e.g., 'Admin', 'Pharmacist', 'Cashier'
  bool get isActive => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  bool get isWholesaleOperator => throw _privateConstructorUsedError;
  bool get isSuperuser => throw _privateConstructorUsedError;
  int get organizationId => throw _privateConstructorUsedError;
  String get organizationName => throw _privateConstructorUsedError;
  String get organizationSlug => throw _privateConstructorUsedError;
  String get organizationAddress => throw _privateConstructorUsedError;
  String get organizationPhone => throw _privateConstructorUsedError;
  String get organizationLogo => throw _privateConstructorUsedError;
  Map<String, bool> get permissions => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call(
      {int id,
      String phoneNumber,
      String role,
      bool isActive,
      String username,
      bool isWholesaleOperator,
      bool isSuperuser,
      int organizationId,
      String organizationName,
      String organizationSlug,
      String organizationAddress,
      String organizationPhone,
      String organizationLogo,
      Map<String, bool> permissions});
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phoneNumber = null,
    Object? role = null,
    Object? isActive = null,
    Object? username = null,
    Object? isWholesaleOperator = null,
    Object? isSuperuser = null,
    Object? organizationId = null,
    Object? organizationName = null,
    Object? organizationSlug = null,
    Object? organizationAddress = null,
    Object? organizationPhone = null,
    Object? organizationLogo = null,
    Object? permissions = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      phoneNumber: null == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      isWholesaleOperator: null == isWholesaleOperator
          ? _value.isWholesaleOperator
          : isWholesaleOperator // ignore: cast_nullable_to_non_nullable
              as bool,
      isSuperuser: null == isSuperuser
          ? _value.isSuperuser
          : isSuperuser // ignore: cast_nullable_to_non_nullable
              as bool,
      organizationId: null == organizationId
          ? _value.organizationId
          : organizationId // ignore: cast_nullable_to_non_nullable
              as int,
      organizationName: null == organizationName
          ? _value.organizationName
          : organizationName // ignore: cast_nullable_to_non_nullable
              as String,
      organizationSlug: null == organizationSlug
          ? _value.organizationSlug
          : organizationSlug // ignore: cast_nullable_to_non_nullable
              as String,
      organizationAddress: null == organizationAddress
          ? _value.organizationAddress
          : organizationAddress // ignore: cast_nullable_to_non_nullable
              as String,
      organizationPhone: null == organizationPhone
          ? _value.organizationPhone
          : organizationPhone // ignore: cast_nullable_to_non_nullable
              as String,
      organizationLogo: null == organizationLogo
          ? _value.organizationLogo
          : organizationLogo // ignore: cast_nullable_to_non_nullable
              as String,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
          _$UserImpl value, $Res Function(_$UserImpl) then) =
      __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String phoneNumber,
      String role,
      bool isActive,
      String username,
      bool isWholesaleOperator,
      bool isSuperuser,
      int organizationId,
      String organizationName,
      String organizationSlug,
      String organizationAddress,
      String organizationPhone,
      String organizationLogo,
      Map<String, bool> permissions});
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phoneNumber = null,
    Object? role = null,
    Object? isActive = null,
    Object? username = null,
    Object? isWholesaleOperator = null,
    Object? isSuperuser = null,
    Object? organizationId = null,
    Object? organizationName = null,
    Object? organizationSlug = null,
    Object? organizationAddress = null,
    Object? organizationPhone = null,
    Object? organizationLogo = null,
    Object? permissions = null,
  }) {
    return _then(_$UserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      phoneNumber: null == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      isWholesaleOperator: null == isWholesaleOperator
          ? _value.isWholesaleOperator
          : isWholesaleOperator // ignore: cast_nullable_to_non_nullable
              as bool,
      isSuperuser: null == isSuperuser
          ? _value.isSuperuser
          : isSuperuser // ignore: cast_nullable_to_non_nullable
              as bool,
      organizationId: null == organizationId
          ? _value.organizationId
          : organizationId // ignore: cast_nullable_to_non_nullable
              as int,
      organizationName: null == organizationName
          ? _value.organizationName
          : organizationName // ignore: cast_nullable_to_non_nullable
              as String,
      organizationSlug: null == organizationSlug
          ? _value.organizationSlug
          : organizationSlug // ignore: cast_nullable_to_non_nullable
              as String,
      organizationAddress: null == organizationAddress
          ? _value.organizationAddress
          : organizationAddress // ignore: cast_nullable_to_non_nullable
              as String,
      organizationPhone: null == organizationPhone
          ? _value.organizationPhone
          : organizationPhone // ignore: cast_nullable_to_non_nullable
              as String,
      organizationLogo: null == organizationLogo
          ? _value.organizationLogo
          : organizationLogo // ignore: cast_nullable_to_non_nullable
              as String,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserImpl implements _User {
  const _$UserImpl(
      {required this.id,
      required this.phoneNumber,
      required this.role,
      required this.isActive,
      this.username = '',
      this.isWholesaleOperator = false,
      this.isSuperuser = false,
      this.organizationId = 0,
      this.organizationName = '',
      this.organizationSlug = '',
      this.organizationAddress = '',
      this.organizationPhone = '',
      this.organizationLogo = '',
      this.permissions = const <String, bool>{}});

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final int id;
  @override
  final String phoneNumber;
  @override
  final String role;
// e.g., 'Admin', 'Pharmacist', 'Cashier'
  @override
  final bool isActive;
  @override
  @JsonKey()
  final String username;
  @override
  @JsonKey()
  final bool isWholesaleOperator;
  @override
  @JsonKey()
  final bool isSuperuser;
  @override
  @JsonKey()
  final int organizationId;
  @override
  @JsonKey()
  final String organizationName;
  @override
  @JsonKey()
  final String organizationSlug;
  @override
  @JsonKey()
  final String organizationAddress;
  @override
  @JsonKey()
  final String organizationPhone;
  @override
  @JsonKey()
  final String organizationLogo;
  @override
  @JsonKey()
  final Map<String, bool> permissions;

  @override
  String toString() {
    return 'User(id: $id, phoneNumber: $phoneNumber, role: $role, isActive: $isActive, username: $username, isWholesaleOperator: $isWholesaleOperator, isSuperuser: $isSuperuser, organizationId: $organizationId, organizationName: $organizationName, organizationSlug: $organizationSlug, organizationAddress: $organizationAddress, organizationPhone: $organizationPhone, organizationLogo: $organizationLogo, permissions: $permissions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.isWholesaleOperator, isWholesaleOperator) ||
                other.isWholesaleOperator == isWholesaleOperator) &&
            (identical(other.isSuperuser, isSuperuser) ||
                other.isSuperuser == isSuperuser) &&
            (identical(other.organizationId, organizationId) ||
                other.organizationId == organizationId) &&
            (identical(other.organizationName, organizationName) ||
                other.organizationName == organizationName) &&
            (identical(other.organizationSlug, organizationSlug) ||
                other.organizationSlug == organizationSlug) &&
            (identical(other.organizationAddress, organizationAddress) ||
                other.organizationAddress == organizationAddress) &&
            (identical(other.organizationPhone, organizationPhone) ||
                other.organizationPhone == organizationPhone) &&
            (identical(other.organizationLogo, organizationLogo) ||
                other.organizationLogo == organizationLogo) &&
            (identical(other.permissions, permissions) ||
                const DeepCollectionEquality().equals(other.permissions, permissions)));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, phoneNumber, role, isActive, username, isWholesaleOperator,
      isSuperuser, organizationId, organizationName, organizationSlug,
      organizationAddress, organizationPhone, organizationLogo,
      const DeepCollectionEquality().hash(permissions));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(
      this,
    );
  }
}

abstract class _User implements User {
  const factory _User(
      {required final int id,
      required final String phoneNumber,
      required final String role,
      required final bool isActive,
      final String username,
      final bool isWholesaleOperator,
      final bool isSuperuser,
      final int organizationId,
      final String organizationName,
      final String organizationSlug,
      final String organizationAddress,
      final String organizationPhone,
      final String organizationLogo,
      final Map<String, bool> permissions}) = _$UserImpl;

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  int get id;
  @override
  String get phoneNumber;
  @override
  String get role;
  @override // e.g., 'Admin', 'Pharmacist', 'Cashier'
  bool get isActive;
  @override
  String get username;
  @override
  bool get isWholesaleOperator;
  @override
  bool get isSuperuser;
  @override
  int get organizationId;
  @override
  String get organizationName;
  @override
  String get organizationSlug;
  @override
  String get organizationAddress;
  @override
  String get organizationPhone;
  @override
  String get organizationLogo;
  @override
  Map<String, bool> get permissions;
  @override
  @JsonKey(ignore: true)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
