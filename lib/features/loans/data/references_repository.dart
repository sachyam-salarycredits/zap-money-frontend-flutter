import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';

class LoanReferenceStatus {
  const LoanReferenceStatus({
    required this.complete,
    required this.count,
    this.requiredCount = 2,
    this.references = const [],
  });

  final bool complete;
  final int count;
  final int requiredCount;
  final List<Map<String, dynamic>> references;

  factory LoanReferenceStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LoanReferenceStatus(complete: false, count: 0);
    }
    final refs = <Map<String, dynamic>>[];
    final raw = json['references'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          refs.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return LoanReferenceStatus(
      complete: json['complete'] == true,
      count: (json['count'] is num)
          ? (json['count'] as num).toInt()
          : int.tryParse('${json['count']}') ?? refs.length,
      requiredCount: (json['required'] is num)
          ? (json['required'] as num).toInt()
          : 2,
      references: refs,
    );
  }
}

class ReferencesRepository {
  ReferencesRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<String?> _customerId() async {
    final raw = await _storage.read(StorageKeys.customerId);
    return raw?.replaceAll('"', '');
  }

  Future<LoanReferenceStatus> fetchStatus() async {
    final customerId = await _customerId();
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Missing customer id');
    }
    final response = await _dio.post(
      ApiEndpoints.getLoanReferences,
      data: {'customer_id': customerId},
    );
    final body = response.data;
    Map<String, dynamic>? data;
    if (body is Map) {
      final raw = body['data'];
      if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      }
    }
    return LoanReferenceStatus.fromJson(data);
  }

  Future<LoanReferenceStatus> saveReferences({
    required String name1,
    required String relation1,
    required String mobile1,
    required String name2,
    required String relation2,
    required String mobile2,
  }) async {
    final customerId = await _customerId();
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Missing customer id');
    }
    final response = await _dio.post(
      ApiEndpoints.saveReferenceNumber,
      data: {
        'customer_id': customerId,
        'reference_json': [
          {
            'name': name1.trim(),
            'relation': relation1.trim(),
            'mobile_number': mobile1.trim(),
          },
          {
            'name': name2.trim(),
            'relation': relation2.trim(),
            'mobile_number': mobile2.trim(),
          },
        ],
      },
    );
    final body = response.data;
    if (body is Map && body['status'] != 200 && body['status'] != '200') {
      throw StateError(body['msg']?.toString() ?? 'Could not save references');
    }
    Map<String, dynamic>? data;
    if (body is Map && body['data'] is Map) {
      data = Map<String, dynamic>.from(body['data'] as Map);
    }
    return LoanReferenceStatus.fromJson(data);
  }
}

final referencesRepositoryProvider = Provider<ReferencesRepository>((ref) {
  return ReferencesRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
