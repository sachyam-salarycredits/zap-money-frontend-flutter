import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../../dashboard/domain/home_snapshot.dart';

class EnachRepository {
  EnachRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<String?> _customerIdRaw() async {
    final raw = await _storage.read(StorageKeys.customerId);
    return raw?.replaceAll('"', '');
  }

  /// Prefer int for APIs / views that use IntegerField (e.g. GetENACHInformation).
  Future<dynamic> _customerIdPayload() async {
    final raw = await _customerIdRaw();
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw) ?? raw;
  }

  Future<String?> _deviceId() async {
    final raw = await _storage.read(StorageKeys.deviceId);
    return raw?.replaceAll('"', '');
  }

  static double? _positiveAmount(dynamic value) {
    if (value == null) return null;
    final n = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (n == null || n <= 0) return null;
    return n;
  }

  /// RN: `response.data[0]` from `/GetENACHInformation`.
  Future<Map<String, dynamic>?> getEnachInformation() async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.getEnachInformation,
      data: {'customer_id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _firstRecord(res.data);
  }

  Future<Map<String, dynamic>?> getBankAccountInformation() async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.getBankAccountInformation,
      data: {'customer_id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _firstRecord(res.data);
  }

  /// Cashfree reads `Bank_Account_Information.Enach_Amount`. StoreBankInfo
  /// overwrites that field with `request.data.enach_amount` (null if omitted),
  /// which wipes a previously set amount. Restore from home NACH when missing.
  Future<Map<String, dynamic>?> ensureEnachAmountOnBank({
    Map<String, dynamic>? enachInfo,
  }) async {
    final bank = await getBankAccountInformation();
    final existing = _positiveAmount(bank?['enach_amount']);
    if (existing != null) {
      return {
        ...?bank,
        'enach_amount': existing.toString(),
      };
    }

    final fromEnach = _positiveAmount(enachInfo?['enach_amount']);
    double? amount = fromEnach;

    if (amount == null) {
      amount = await _nachAmountFromHome();
    }

    if (amount == null) {
      return bank;
    }

    final name = (bank?['customer_name'] ?? enachInfo?['customer_name'])
        ?.toString();
    final account = (bank?['bank_account_number'] ??
            enachInfo?['bank_account_number'])
        ?.toString();
    final ifsc = (bank?['ifsc_code'] ?? enachInfo?['ifsc_code'])?.toString();
    final bankName = bank?['bank_name']?.toString() ?? '';
    final branch = bank?['branch_name']?.toString() ?? '';
    final customerId = await _customerIdPayload();
    final deviceId = await _deviceId();

    if (account == null ||
        account.isEmpty ||
        ifsc == null ||
        ifsc.isEmpty ||
        customerId == null) {
      return {
        ...?bank,
        'enach_amount': amount.toString(),
      };
    }

    try {
      await _dio.post(
        ApiEndpoints.storeBankInfo,
        data: {
          'deviceId': deviceId,
          'customer_name': name ?? '',
          'customer_id': customerId,
          'sf_record_id': bank?['sf_record_id']?.toString() ?? '',
          'ifsc_code': ifsc,
          'bank_account_number': account,
          'bank_name': bankName,
          'branch_name': branch,
          'enach_amount': amount.toString(),
        },
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
        ),
      );
    } catch (_) {
      // Still return resolved amount for UI; createSource may still fail.
    }

    return {
      ...?bank,
      'customer_name': name,
      'bank_account_number': account,
      'ifsc_code': ifsc,
      'bank_name': bankName,
      'branch_name': branch,
      'enach_amount': amount.toString(),
    };
  }

  Future<double?> _nachAmountFromHome() async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.homeScreenInformation,
      data: {'Customer_Id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    if (data is! Map) return null;
    final home = HomeSnapshot.fromJson(
      data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data),
    );
    return _positiveAmount(home.nachAmount) ??
        _positiveAmount(home.emiAmount);
  }

  Future<bool> isUpiEnabled() async {
    try {
      final res = await _dio.post(
        ApiEndpoints.upiConfigStatus,
        data: <dynamic>[],
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'clearHeader': true},
        ),
      );
      final data = res.data;
      if (data is Map) return data['status']?.toString() == 'True';
    } catch (_) {}
    return false;
  }

  Future<void> storeEmiDate(String emiDay) async {
    final customerId = await _customerIdPayload();
    await _dio.post(
      ApiEndpoints.storeEmiInformation,
      data: {
        'customer_id': customerId,
        'customer_emi_date': emiDay,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  Future<Map<String, dynamic>?> createSource({required String authMode}) async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.enachSourceIdCreation,
      data: {
        'customerid': customerId,
        'authMode': authMode,
        'auth_mode': authMode,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return _asMap(res.data);
  }

  Future<bool> checkSourceStatus() async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.checkSourceStatus,
      data: {'customerid': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    if (data is Map) return data['status']?.toString() == 'True';
    return false;
  }

  Future<Map<String, dynamic>?> validateVpa({
    required String vpa,
    required String contractId,
  }) async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.validateVpa,
      data: {
        'cid': customerId,
        'payerVirAddr': vpa,
        'contract_id': contractId,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>?> createUpiMandate({
    required String vpa,
    required String amount,
    required String contractId,
    required String validityStart,
    required String validityEnd,
  }) async {
    final customerId = await _customerIdPayload();
    final res = await _dio.post(
      ApiEndpoints.createMandate,
      data: {
        'customer_id': customerId,
        'validityStart': validityStart,
        'validityEnd': validityEnd,
        'payerVirAddr': vpa,
        'amount': amount,
        'contract_id': contractId,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return _asMap(res.data);
  }

  Future<bool> isUpiMandateApproved(String contractId) async {
    final res = await _dio.post(
      ApiEndpoints.upiCurrentStatus,
      data: {'contract_id': contractId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = res.data;
    if (data is! Map) return false;
    return data['resdec']?.toString() == 'Approved' && data['status'] == true;
  }

  static Map<String, dynamic>? _firstRecord(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) {
      final inner = data['data'];
      if (inner is List && inner.isNotEmpty && inner.first is Map) {
        return Map<String, dynamic>.from(inner.first as Map);
      }
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

final enachRepositoryProvider = Provider<EnachRepository>((ref) {
  return EnachRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
