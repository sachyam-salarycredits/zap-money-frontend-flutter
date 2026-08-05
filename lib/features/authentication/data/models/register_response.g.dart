// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegisterResponse _$RegisterResponseFromJson(Map<String, dynamic> json) =>
    _RegisterResponse(
      status: (json['status'] as num?)?.toInt(),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$RegisterResponseToJson(_RegisterResponse instance) =>
    <String, dynamic>{'status': instance.status, 'message': instance.message};
