// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_verify_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OtpVerifyResponse _$OtpVerifyResponseFromJson(Map<String, dynamic> json) =>
    _OtpVerifyResponse(
      status: (json['status'] as num?)?.toInt(),
      customerId: json['customer_Id'],
      deviceId: json['device_id'],
      accessToken: json['access_token'] as String?,
      refresh: json['refresh'] as String?,
      customerType: json['customer_type'],
      appsflyerId: json['appsflyer_id'],
    );

Map<String, dynamic> _$OtpVerifyResponseToJson(_OtpVerifyResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'customer_Id': instance.customerId,
      'device_id': instance.deviceId,
      'access_token': instance.accessToken,
      'refresh': instance.refresh,
      'customer_type': instance.customerType,
      'appsflyer_id': instance.appsflyerId,
    };
