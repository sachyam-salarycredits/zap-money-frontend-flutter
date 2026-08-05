import 'package:freezed_annotation/freezed_annotation.dart';

part 'otp_verify_response.freezed.dart';
part 'otp_verify_response.g.dart';

@freezed
abstract class OtpVerifyResponse with _$OtpVerifyResponse {
  const factory OtpVerifyResponse({
    int? status,
    @JsonKey(name: 'customer_Id') dynamic customerId,
    @JsonKey(name: 'device_id') dynamic deviceId,
    @JsonKey(name: 'access_token') String? accessToken,
    @JsonKey(name: 'refresh') String? refresh,
    @JsonKey(name: 'customer_type') dynamic customerType,
    @JsonKey(name: 'appsflyer_id') dynamic appsflyerId,
  }) = _OtpVerifyResponse;

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpVerifyResponseFromJson(json);
}
