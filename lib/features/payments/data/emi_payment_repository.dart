import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';

class EmiCheckoutResult {
  const EmiCheckoutResult({
    required this.platformBillId,
    required this.upiUrl,
    this.mockPaid = false,
  });

  final String platformBillId;
  final String upiUrl;
  final bool mockPaid;
}

class EmiPaymentRepository {
  EmiPaymentRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<String?> _customerId() async {
    final raw = await _storage.read(StorageKeys.customerId);
    return raw?.replaceAll('"', '');
  }

  /// RN `resolveUpiLinkUrl` — Cashfree may return a string or app-keyed map.
  static String? resolveUpiLinkUrl(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final link = raw.trim();
      return link.isEmpty ? null : link;
    }
    if (raw is Map) {
      for (final key in ['default', 'gpay', 'phonepe', 'paytm', 'bhim', 'web']) {
        final val = raw[key];
        if (val is String && val.trim().isNotEmpty) return val.trim();
      }
      for (final val in raw.values) {
        if (val is String && val.trim().isNotEmpty) return val.trim();
      }
    }
    return null;
  }

  /// RN home Pre-Pay → `CashfreeEmiPayment` with `{ amount, contractId, cid }`.
  Future<EmiCheckoutResult> createEmiCheckout({
    required num amount,
    required String contractId,
  }) async {
    final customerId = await _customerId();
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Missing customer id');
    }

    final res = await _dio.post(
      ApiEndpoints.cashfreeEmiPayment,
      data: {
        'amount': amount is double ? amount.round() : amount,
        'contractId': contractId,
        'cid': int.tryParse(customerId) ?? customerId,
      },
      options: Options(contentType: Headers.jsonContentType),
    );

    final body = res.data;
    final map = body is Map<String, dynamic>
        ? body
        : body is Map
            ? Map<String, dynamic>.from(body)
            : <String, dynamic>{};

    final data = map['Data'] is Map
        ? Map<String, dynamic>.from(map['Data'] as Map)
        : map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : <String, dynamic>{};

    final billId = (data['PlatformBillId'] ??
            data['platformBillID'] ??
            data['platformBillId'] ??
            '')
        .toString();
    final upiUrl = resolveUpiLinkUrl(
          data['UPILinkURL'] ??
              data['upiLinkURL'] ??
              (data['paymentLink'] is Map
                  ? (data['paymentLink'] as Map)['shortURL']
                  : null),
        ) ??
        '';

    if (billId.isEmpty || upiUrl.isEmpty) {
      throw StateError('EMI payment link unavailable');
    }

    return EmiCheckoutResult(
      platformBillId: billId,
      upiUrl: upiUrl,
      mockPaid: map['MockPaid'] == true,
    );
  }
}

final emiPaymentRepositoryProvider = Provider<EmiPaymentRepository>((ref) {
  return EmiPaymentRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
