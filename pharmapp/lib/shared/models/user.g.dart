// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: (json['id'] as num).toInt(),
      phoneNumber: json['phoneNumber'] as String,
      role: json['role'] as String,
      isActive: json['isActive'] as bool,
      username: json['username'] as String? ?? '',
      isWholesaleOperator: json['isWholesaleOperator'] as bool? ?? false,
      organizationId: (json['organizationId'] as num?)?.toInt() ?? 0,
      organizationName: json['organizationName'] as String? ?? '',
      organizationSlug: json['organizationSlug'] as String? ?? '',
      organizationAddress: json['organizationAddress'] as String? ?? '',
      organizationPhone: json['organizationPhone'] as String? ?? '',
      permissions: (json['permissions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const <String, bool>{},
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phoneNumber': instance.phoneNumber,
      'role': instance.role,
      'isActive': instance.isActive,
      'username': instance.username,
      'isWholesaleOperator': instance.isWholesaleOperator,
      'organizationId': instance.organizationId,
      'organizationName': instance.organizationName,
      'organizationSlug': instance.organizationSlug,
      'organizationAddress': instance.organizationAddress,
      'organizationPhone': instance.organizationPhone,
      'permissions': instance.permissions,
    };
