import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';

class CkycRepository {
  CkycRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Options get _bearerJson => Options(
        contentType: Headers.jsonContentType,
        extra: {'useBearer': true},
      );

  Future<String?> _customerId() async {
    final raw = await _storage.read(StorageKeys.customerId);
    return raw?.replaceAll('"', '');
  }

  Future<Map<String, dynamic>> status() async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.ckycStatus,
      data: {'customer_id': customerId},
      options: _bearerJson,
    );
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> search({String? pan}) async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.ckycSearch,
      data: {
        'customer_id': customerId,
        if (pan != null && pan.isNotEmpty) 'pan': pan,
      },
      options: _bearerJson,
    );
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> selectHit({
    required int sessionId,
    required String referenceId,
  }) async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.ckycSelect,
      data: {
        'customer_id': customerId,
        'sessionId': sessionId,
        'referenceId': referenceId,
      },
      options: _bearerJson,
    );
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> generateOtp({
    required int sessionId,
    String authFactorType = '01',
    String? authFactorValue,
  }) async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.ckycOtpGenerate,
      data: {
        'customer_id': customerId,
        'sessionId': sessionId,
        'authFactorType': authFactorType,
        if (authFactorValue != null) 'authFactorValue': authFactorValue,
        'maskAadhaar': true,
      },
      options: _bearerJson,
    );
    return _unwrap(res.data);
  }

  /// Optional P1 fetch-analyze; not used in the CKYC funnel unless backend enables it.
  Future<Map<String, dynamic>> analyze({
    double? nameMatchThreshold,
    double? imageQualityThreshold,
  }) async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.ckycAnalyze,
      data: {
        'customer_id': customerId,
        if (nameMatchThreshold != null) 'nameMatchThreshold': nameMatchThreshold,
        if (imageQualityThreshold != null)
          'imageQualityThreshold': imageQualityThreshold,
      },
      options: _bearerJson,
    );
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> validateOtp({
    required int sessionId,
    required String otp,
  }) async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.ckycOtpValidate,
      data: {
        'customer_id': customerId,
        'sessionId': sessionId,
        'otp': otp,
        'maskAadhaar': true,
      },
      options: _bearerJson,
    );
    return _unwrap(res.data);
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}

final ckycRepositoryProvider = Provider<CkycRepository>((ref) {
  return CkycRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
