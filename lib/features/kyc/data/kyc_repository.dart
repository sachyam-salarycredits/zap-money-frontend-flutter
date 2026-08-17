import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';

class EmailVerificationException implements Exception {
  const EmailVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KycRepository {
  KycRepository(this._dio, this._storage);

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

  /// RN sends `CustomerId` as a number when possible.
  Future<dynamic> _customerIdForDigilocker() async {
    final id = await _customerId();
    if (id == null || id.isEmpty) return id;
    return int.tryParse(id) ?? id;
  }

  Future<String?> _sfCustomerId() async {
    final raw = await _storage.read(StorageKeys.sfCustomerId);
    return raw?.replaceAll('"', '');
  }

  Future<Map<String, dynamic>?> getCustomerInfo() async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.getCustomerInfo,
      data: {'customer_id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty) {
      return Map<String, dynamic>.from((data['data'] as List).first as Map);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<String?> createVkycLink({
    required String panDob,
    required String panName,
  }) async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.createKycLink,
      data: {
        'customer_id': customerId,
        'panDOB': panDob,
        'panName': panName,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    if (data is Map) {
      final nested = data['data'];
      if (nested is Map && nested['url'] != null) {
        return nested['url'].toString();
      }
      if (data['url'] != null) return data['url'].toString();
    }
    return null;
  }

  Future<bool> isVkycPassed() async {
    final customerId = await _customerId();
    final res = await _dio.post(
      ApiEndpoints.vkycResponseCheck,
      data: {'customerid': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    Map? record;
    if (data is Map && data['records'] is List && (data['records'] as List).isNotEmpty) {
      record = (data['records'] as List).first as Map?;
    } else if (data is Map && data['data'] is Map && data['data']['records'] is List) {
      final records = data['data']['records'] as List;
      if (records.isNotEmpty) record = records.first as Map?;
    }
    if (record == null) return false;
    if (record['Final_KYC_Status__c'] != null) return true;
    return record['PAN_OCR_Agent_Decision__c']?.toString() == 'VERIFIED' &&
        record['Face_verification_decision_by_agent__c']?.toString() ==
            'VERIFIED';
  }

  Future<Map<String, dynamic>?> digilockerCreate() async {
    final customerId = await _customerIdForDigilocker();
    final res = await _dio.post(
      ApiEndpoints.digilockerCreateUrl,
      data: {'CustomerId': customerId},
      options: _bearerJson,
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>?> digilockerPoll({
    required String verificationId,
  }) async {
    final customerId = await _customerIdForDigilocker();
    final res = await _dio.get(
      ApiEndpoints.digilockerStatus,
      queryParameters: {
        'CustomerId': customerId,
        'verificationId': verificationId,
      },
      options: Options(extra: {'useBearer': true}),
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>?> digilockerComplete({
    required String verificationId,
  }) async {
    final customerId = await _customerIdForDigilocker();
    final res = await _dio.post(
      ApiEndpoints.digilockerComplete,
      data: {
        'CustomerId': customerId,
        'verificationId': verificationId,
      },
      options: _bearerJson,
    );
    final map = _asMap(res.data);
    if (kDebugMode) {
      debugPrint('digilockerComplete → $map');
    }
    return map;
  }

  /// DigiLocker document can lag a moment after AUTHENTICATED.
  Future<Map<String, dynamic>?> digilockerCompleteWithRetry({
    required String verificationId,
  }) async {
    Map<String, dynamic>? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
      }
      last = await digilockerComplete(verificationId: verificationId);
      if (extractAadhaarName(last) != null) return last;
      // Soft API errors (HTTP 200 + status/msg) won't gain a name on retry
      // unless it's a transient empty document.
      final status = last?['status'];
      if (status == 400 ||
          status == 403 ||
          status == 404 ||
          status == 503 ||
          status == '400' ||
          status == '403' ||
          status == '404' ||
          status == '503') {
        return last;
      }
    }
    return last;
  }

  static String? extractAadhaarName(Map<String, dynamic>? completed) {
    if (completed == null) return null;
    final result = completed['result'];
    if (result is Map) {
      for (final key in ['name', 'full_name', 'Name', 'fullName']) {
        final value = result[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    // Some gateways flatten the payload.
    for (final key in ['name', 'full_name', 'Name']) {
      final value = completed[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? extractErrorMessage(Map<String, dynamic>? completed) {
    if (completed == null) return null;
    final msg = (completed['msg'] ?? completed['message'] ?? completed['error'])
        ?.toString()
        .trim();
    if (msg != null && msg.isNotEmpty) return msg;
    return null;
  }

  Future<bool> uploadDkycFrontend({
    required String customerName,
    String? aadhaarNumber,
  }) async {
    final customerId = await _customerId();
    final sfId = await _sfCustomerId() ?? customerId;
    final res = await _dio.post(
      ApiEndpoints.uploadDkycResponse,
      data: {
        'Sf_Customer_Id': sfId,
        'Customer_Id': customerId,
        'Customer_Name': customerName,
        'Aadhaar_Number': aadhaarNumber ?? '',
        'Aadhar_Match': 'yes',
        'Aadhar_MatchScore': '100',
        'Aadhar_Status': 'DIGILOCKER',
        'Liveness_Score': null,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    if (data is! Map) return false;
    final status = data['status'] ?? data['StatusCode'];
    final msg = (data['msg'] ?? data['StatusMessage'] ?? '').toString();
    final already = msg.toLowerCase().contains('already exist');
    return status == 200 || status == '200' || already;
  }

  Future<void> sendEmailVerification(String email) async {
    final customerId = await _customerId();
    final response = await _dio.post(
      ApiEndpoints.verifyUserEmail,
      data: {
        'customer_id': customerId,
        'email': email,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final body = _asMap(response.data);
    final status = body?['status']?.toString();
    if (status != null && status != '200') {
      final message = (body?['message'] ?? body?['msg'] ?? body?['error'])
          ?.toString()
          .trim();
      throw EmailVerificationException(
        message?.isNotEmpty == true
            ? message!
            : 'Could not send verification email',
      );
    }
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        return _asMap(decoded);
      } catch (_) {
        return null;
      }
    }
    if (data is Map<String, dynamic>) {
      // Some proxies wrap as { data: { ... } }
      final nested = data['data'];
      if (nested is Map &&
          (data['result'] == null && data['verificationId'] == null) &&
          (nested['result'] != null ||
              nested['verificationId'] != null ||
              nested['url'] != null ||
              nested['msg'] != null)) {
        return Map<String, dynamic>.from(nested);
      }
      return data;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return KycRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
