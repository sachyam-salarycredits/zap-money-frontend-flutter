import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';

class EsignStatus {
  const EsignStatus({
    required this.exists,
    this.signingStatus,
    this.signingLink,
    this.signedS3Url,
    this.isSigned = false,
    this.canResend = true,
  });

  final bool exists;
  final String? signingStatus;
  final String? signingLink;
  final String? signedS3Url;
  final bool isSigned;
  final bool canResend;

  factory EsignStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EsignStatus(exists: false);
    }
    return EsignStatus(
      exists: json['exists'] == true || json['signing_status'] != null,
      signingStatus: json['signing_status']?.toString(),
      signingLink: json['signing_link']?.toString(),
      signedS3Url: json['signed_s3_url']?.toString(),
      isSigned: json['is_signed'] == true,
      canResend: json['can_resend'] != false,
    );
  }
}

class EsignRepository {
  EsignRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<String?> _customerId() async {
    final raw = await _storage.read(StorageKeys.customerId);
    return raw?.replaceAll('"', '');
  }

  Future<EsignStatus> fetchStatus({bool refresh = false}) async {
    final customerId = await _customerId();
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Missing customer id');
    }
    final response = await _dio.post(
      ApiEndpoints.esignStatus,
      data: {
        'customer_id': customerId,
        'refresh': refresh,
      },
    );
    final body = response.data;
    Map<String, dynamic>? data;
    if (body is Map) {
      final raw = body['data'];
      if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      }
    }
    return EsignStatus.fromJson(data);
  }
}

final esignRepositoryProvider = Provider<EsignRepository>((ref) {
  return EsignRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
