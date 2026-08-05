import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/auth_token_service.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/services/screen_status_resolver.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/otp_verify_response.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  static Options get _jsonOptions => Options(
        contentType: Headers.jsonContentType,
        headers: {
          Headers.contentTypeHeader: Headers.jsonContentType,
          Headers.acceptHeader: Headers.jsonContentType,
        },
      );

  Future<Response<dynamic>> registerDevice(Map<String, dynamic> body) {
    return _dio.post(
      ApiEndpoints.validateDevice,
      data: body,
      options: _jsonOptions,
    );
  }

  Future<Response<dynamic>> loginWithOtp(Map<String, dynamic> body) {
    return _dio.post(
      ApiEndpoints.verifyOtp,
      data: body,
      options: _jsonOptions,
    );
  }

  Future<Response<dynamic>> screenStatus(Map<String, dynamic> body) {
    return _dio.post(
      ApiEndpoints.getScreenCompletionflags,
      data: body,
      options: _jsonOptions,
    );
  }

  Future<Response<dynamic>> profileInfo(Map<String, dynamic> body) {
    return _dio.post(
      ApiEndpoints.getProfileInfo,
      data: body,
      options: _jsonOptions,
    );
  }

  Future<Response<dynamic>> buildVersion() {
    return _dio.get(ApiEndpoints.updateVersion);
  }

  Future<Response<dynamic>> sfAccountStatus(Map<String, dynamic> body) {
    return _dio.post(
      ApiEndpoints.getSFAccountStatus,
      data: body,
      options: _jsonOptions,
    );
  }

  Future<Response<dynamic>> vkycResponseCheck(Map<String, dynamic> body) {
    return _dio.post(
      ApiEndpoints.vkycResponseCheck,
      data: body,
      options: _jsonOptions,
    );
  }
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SessionStorage storage,
    required AuthTokenService tokenService,
    required DeviceIdService deviceIdService,
  })  : _remote = remote,
        _storage = storage,
        _tokenService = tokenService,
        _deviceIdService = deviceIdService;

  final AuthRemoteDataSource _remote;
  final SessionStorage _storage;
  final AuthTokenService _tokenService;
  final DeviceIdService _deviceIdService;

  @override
  Future<bool> sendOtp({
    required String mobileNumber,
    String hash = '',
    String appVersion = '',
  }) async {
    // RN validateDevice always injects getUniqueId() as device_imei — never DB device_id.
    final deviceImei = await _deviceIdService.getHardwareImei();
    final version = appVersion.trim().isEmpty ? '1.0.0' : appVersion.trim();
    try {
      final response = await _remote.registerDevice({
        'mobile_number': mobileNumber,
        'hash': hash,
        'app_version': version,
        'device_imei': deviceImei,
      });
      final data = response.data;
      final status = data is Map ? data['status'] : null;
      if (status == 200 || status == '200') {
        await _storage.write(StorageKeys.mobileNo, mobileNumber);
        if (kDebugMode) {
          debugPrint(
            'Register_api OK for $mobileNumber '
            '(newUser=${data is Map ? data['newUser'] : null}, imei=$deviceImei). '
            'If SMS is mocked, OTP is in Django logs: [MockSms] OTP for …',
          );
        }
        return true;
      }
      if (kDebugMode) {
        debugPrint(
          'Register_api non-200 body (http=${response.statusCode}): $data',
        );
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Register_api DioException http=${e.response?.statusCode} '
          'url=${e.requestOptions.uri} data=${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession?> verifyOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final response = await _remote.loginWithOtp({
        'mobile_number': mobileNumber,
        'otp': otp,
      });
      final data = response.data;
      if (kDebugMode) {
        debugPrint('login_api response → $data');
      }
      if (data is! Map) return null;
      return _parseOtpMap(Map<String, dynamic>.from(data), mobileNumber);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'login_api DioException http=${e.response?.statusCode} '
          'data=${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  Future<AuthSession?> _parseOtpMap(
    Map<String, dynamic> data,
    String mobileNumber,
  ) async {
    // Match RN verifyOtp success branches (status 200 OR server_response.code 200).
    Map<String, dynamic> payload = data;
    final status = data['status'];
    final okStatus = status == 200 || status == '200';
    if (!okStatus) {
      final server = data['server_response'];
      if (server is Map &&
          (server['code'] == 200 || server['code'] == '200')) {
        payload = Map<String, dynamic>.from(server);
      } else {
        if (kDebugMode) {
          debugPrint('login_api rejected: ${data['msg'] ?? data}');
        }
        return null;
      }
    }

    final parsed = OtpVerifyResponse.fromJson(payload);
    final accessToken = parsed.accessToken;
    final deviceId = _stringify(parsed.deviceId);
    // New users: backend returns customer_Id: "" — RN still accepts the session.
    final customerId = _stringify(parsed.customerId);

    if (accessToken == null ||
        accessToken.isEmpty ||
        deviceId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'login_api parse failed: token=${accessToken != null} '
          'deviceId="$deviceId" customerId="$customerId"',
        );
      }
      return null;
    }

    await _storage.write(StorageKeys.mobileNo, mobileNumber);
    await _storage.write(StorageKeys.deviceId, jsonEncode(deviceId));
    await _storage.write(StorageKeys.customerId, jsonEncode(customerId));
    await _storage.write(
      StorageKeys.userType,
      jsonEncode(_stringify(parsed.customerType)),
    );
    await _tokenService.persistLoginAccessToken(
      accessToken,
      refreshToken: parsed.refresh,
    );

    return AuthSession(
      mobileNumber: mobileNumber,
      customerId: customerId,
      deviceId: deviceId,
      accessToken: accessToken,
      refreshToken: parsed.refresh,
      userType: _stringify(parsed.customerType),
    );
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.replaceAll('"', '');
    return value.toString();
  }

  @override
  Future<ScreenCompletionFlags> fetchScreenFlags(String deviceId) async {
    // RN biometric uses `Device_Id`; home sometimes uses `device_Id` — send both.
    final response = await _remote.screenStatus({
      'Device_Id': deviceId,
      'device_Id': deviceId,
    });
    final data = response.data;
    if (data is List) {
      return ScreenCompletionFlags.fromScreenList(data);
    }
    if (data is Map && data['data'] is List) {
      return ScreenCompletionFlags.fromScreenList(data['data'] as List);
    }
    return const ScreenCompletionFlags();
  }

  @override
  Future<ProfileSnapshot?> fetchProfile({
    required String customerId,
    required String deviceId,
  }) async {
    final response = await _remote.profileInfo({
      'customer_id': customerId,
      'device_id': deviceId,
    });
    final root = response.data;
    if (root is! Map) return null;
    final data = root['data'];
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final sfId = map['sf_customer_id']?.toString();
    if (sfId != null && sfId.isNotEmpty) {
      await _storage.write(StorageKeys.sfCustomerId, sfId);
    }
    return ProfileSnapshot(
      userType: map['userType']?.toString(),
      customerPlan: map['customer_plan']?.toString() ?? '1',
      sfCustomerId: sfId,
      firstName: map['firstName']?.toString(),
      lastName: map['lastName']?.toString(),
    );
  }

  @override
  Future<bool> hasStoredSession() async {
    final token = await _storage.read(StorageKeys.token);
    final deviceId = await _storage.read(StorageKeys.deviceId);
    return token != null &&
        token.isNotEmpty &&
        deviceId != null &&
        deviceId.isNotEmpty;
  }

  @override
  Future<AuthSession?> readStoredSession() async {
    final mobile = await _storage.read(StorageKeys.mobileNo);
    final customerId = (await _storage.read(StorageKeys.customerId))
        ?.replaceAll('"', '');
    final deviceId =
        (await _storage.read(StorageKeys.deviceId))?.replaceAll('"', '');
    final tokenRaw = await _storage.read(StorageKeys.token);
    final userType =
        (await _storage.read(StorageKeys.userType))?.replaceAll('"', '');
    if (mobile == null ||
        customerId == null ||
        deviceId == null ||
        tokenRaw == null) {
      return null;
    }
    var token = tokenRaw;
    if (token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1);
    }
    return AuthSession(
      mobileNumber: mobile,
      customerId: customerId,
      deviceId: deviceId,
      accessToken: token,
      userType: userType,
    );
  }

  @override
  Future<void> refreshSfCustomerIdForBiometricLogin() async {
    // RN login: remove sfCustomerId, then GetSFAccountStatus by mobile.
    await _storage.delete(StorageKeys.sfCustomerId);
    final mobile = await _storage.read(StorageKeys.mobileNo);
    if (mobile == null || mobile.isEmpty) return;
    try {
      final response = await _remote.sfAccountStatus({
        'device_id': null,
        'mobile_number': mobile,
      });
      final sfId = _parseSfCustomerId(response.data);
      if (sfId != null && sfId.isNotEmpty) {
        await _storage.write(StorageKeys.sfCustomerId, sfId);
      }
    } catch (_) {
      // Non-blocking — same as RN `.then` without failing biometric.
    }
  }

  String? _parseSfCustomerId(dynamic data) {
    if (data is! Map) return null;
    final customer = data['Customer'] ?? data['customer'];
    if (customer is Map) {
      final records = customer['records'];
      if (records is List && records.isNotEmpty) {
        final first = records.first;
        if (first is Map) {
          final id = first['Customer_ID__c'] ?? first['Customer_Id__c'];
          if (id != null) return id.toString();
        }
      }
    }
    final direct = data['Customer_ID__c'] ?? data['sf_customer_id'];
    return direct?.toString();
  }

  @override
  Future<bool> isKycComplete() async {
    final customerId = (await _storage.read(StorageKeys.customerId))
        ?.replaceAll('"', '');
    if (customerId == null || customerId.isEmpty) return false;
    try {
      final response = await _remote.vkycResponseCheck({
        'customerid': customerId,
      });
      final data = response.data;
      Map? record;
      if (data is Map &&
          data['records'] is List &&
          (data['records'] as List).isNotEmpty) {
        record = (data['records'] as List).first as Map?;
      } else if (data is Map &&
          data['data'] is Map &&
          data['data']['records'] is List) {
        final records = data['data']['records'] as List;
        if (records.isNotEmpty) record = records.first as Map?;
      }
      if (record == null) return false;
      if (record['Final_KYC_Status__c'] != null) return true;
      return record['PAN_OCR_Agent_Decision__c']?.toString() == 'VERIFIED' &&
          record['Face_verification_decision_by_agent__c']?.toString() ==
              'VERIFIED';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> checkAppVersion() async {
    try {
      final response = await _remote.buildVersion();
      final data = response.data;
      if (data is Map) return data['zap_build_version']?.toString();
    } catch (_) {}
    return null;
  }
}
