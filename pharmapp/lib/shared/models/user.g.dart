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
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phoneNumber': instance.phoneNumber,
      'role': instance.role,
      'isActive': instance.isActive,
      'username': instance.username,
      'isWholesaleOperator': instance.isWholesaleOperator,
    };
