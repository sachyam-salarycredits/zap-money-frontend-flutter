import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/services/screen_status_resolver.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';

class ProfileRepository {
  ProfileRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<Map<String, dynamic>?> fetchProfile() async {
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final deviceId =
        (await _storage.read(StorageKeys.deviceId))?.replaceAll('"', '');
    final response = await _dio.post(
      ApiEndpoints.getProfileInfo,
      data: {
        'customer_id': customerId,
        'device_id': deviceId,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<ScreenCompletionFlags> fetchFlags() async {
    final deviceId =
        (await _storage.read(StorageKeys.deviceId))?.replaceAll('"', '');
    if (deviceId == null || deviceId.isEmpty) {
      return const ScreenCompletionFlags();
    }
    final response = await _dio.post(
      ApiEndpoints.getScreenCompletionflags,
      data: {'device_Id': deviceId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map && raw['data'] is List)
            ? raw['data'] as List
            : const [];
    return ScreenCompletionFlags.fromScreenList(list);
  }

  Future<Map<String, dynamic>?> fetchCustomerInformation() async {
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final response = await _dio.post(
      ApiEndpoints.customerInformation,
      data: {'customer_id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  /// RN `userAddress` → `officeAddress` from `/customerInformation`.
  Future<Map<String, dynamic>?> fetchOfficeAddress() async {
    final info = await fetchCustomerInformation();
    if (info == null) return null;
    final office = info['officeAddress'];
    if (office is Map) return Map<String, dynamic>.from(office);
    return null;
  }

  /// RN residential address block from the same endpoint.
  Future<Map<String, dynamic>?> fetchResidentialAddress() async {
    final info = await fetchCustomerInformation();
    if (info == null) return null;
    final residential = info['residentialAddress'] ?? info['address'];
    if (residential is Map) return Map<String, dynamic>.from(residential);
    return null;
  }

  Future<Map<String, dynamic>?> fetchLoanStatus(String contractId) async {
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final response = await _dio.post(
      ApiEndpoints.loanStatus,
      data: {
        'contractId': contractId,
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  /// RN `POST /Loan-Contract-PDF`.
  ///
  /// New backend returns a single document with `PublicURL` / `DownloadURL`.
  /// Legacy SF-era payload used `offerAccept[]` (still supported).
  Future<List<Map<String, dynamic>>> fetchLoanContractPdfs() async {
    final sfId =
        (await _storage.read(StorageKeys.sfCustomerId))?.replaceAll('"', '');
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final id = (sfId != null && sfId.isNotEmpty) ? sfId : customerId;
    if (id == null || id.isEmpty) return const [];

    final response = await _dio.post(
      ApiEndpoints.loanContractPdf,
      data: {'customerId': id},
      options: Options(contentType: Headers.jsonContentType),
    );
    final body = response.data;
    Map? root;
    if (body is Map && body['data'] is Map) {
      root = body['data'] as Map;
    } else if (body is Map) {
      root = body;
    }
    if (root == null) return const [];

    if (root['offerAccept'] is List) {
      return (root['offerAccept'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final url = (root['PublicURL'] ?? root['DownloadURL'] ?? root['public_url'])
        ?.toString();
    if (url != null && url.isNotEmpty) {
      return [
        {
          'DocumentName': root['DocumentName'] ?? 'Loan Contract',
          'PublicURL': url,
          'DownloadURL': root['DownloadURL'] ?? url,
          'disbursement': {
            'loanAmt': root['loanAmt'] ?? root['amount'],
            'dt': root['dt'] ?? root['date'],
          },
          'lai': root['lai'] ?? root['contractId'],
        },
      ];
    }
    return const [];
  }

  /// RN `uploadUserDocument` → `POST /save_document` for salary slips.
  Future<bool> uploadSalarySlip({
    required String documentName,
    required String filePath,
    required String fileName,
    String password = '',
  }) async {
    final customerId =
        (await _storage.read(StorageKeys.customerId))?.replaceAll('"', '');
    final sfId =
        (await _storage.read(StorageKeys.sfCustomerId))?.replaceAll('"', '');
    final form = FormData.fromMap({
      'document_name': documentName,
      'sf_customer_id': sfId,
      'customer_id': customerId,
      'password': password,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });
    final response = await _dio.post(
      ApiEndpoints.saveDocument,
      data: form,
    );
    final body = response.data;
    if (body is Map) {
      final status = body['status'];
      return status == 200 || status == '200';
    }
    return response.statusCode == 200;
  }

  Future<void> logout() async {
    try {
      final storageToken = await _storage.readJson(StorageKeys.storageToken);
      final accessToken = storageToken?['token'] as String?;
      final fallbackAccess = _stripQuotes(await _storage.read(StorageKeys.token));
      final token = (accessToken != null && accessToken.isNotEmpty)
          ? accessToken
          : fallbackAccess;

      if (token != null && token.isNotEmpty) {
        await _dio.post(
          ApiEndpoints.logoutApi,
          data: const <String, dynamic>{},
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {
              'token': token,
              'Authorization': 'Bearer $token',
            },
            // Skip interceptor guest/oauth token — logout requires login JWT.
            extra: {'clearHeader': true},
          ),
        );
      }
    } catch (_) {
      // Always clear local session even if the server call fails.
    }
    await _storage.clearUserSession();
  }

  /// Keeps RN-parity name used by profile hub.
  Future<void> logoutLocal() => logout();

  String? _stripQuotes(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length >= 2) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed.replaceAll('"', '');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
