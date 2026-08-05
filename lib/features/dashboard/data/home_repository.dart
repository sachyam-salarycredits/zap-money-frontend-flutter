import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/services/screen_status_resolver.dart';
import '../../../core/storage/session_storage.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../domain/home_snapshot.dart';

class HomeBundle {
  const HomeBundle({
    required this.home,
    required this.flags,
    this.creditDecision,
    this.userType,
  });

  final HomeSnapshot home;
  final ScreenCompletionFlags flags;
  final CreditDecisionSummary? creditDecision;
  final String? userType;
}

class CreditDecisionSummary {
  const CreditDecisionSummary({
    this.status,
    this.maxLoanAmount,
    this.minLoanAmount,
  });

  final String? status;
  final double? maxLoanAmount;
  final double? minLoanAmount;

  factory CreditDecisionSummary.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    return CreditDecisionSummary(
      status: json['status']?.toString(),
      maxLoanAmount: asDouble(json['max_loan_amount']),
      minLoanAmount: asDouble(json['min_loan_amount']),
    );
  }
}

class HomeRepository {
  HomeRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<String?> _customerId() async {
    final raw = await _storage.read(StorageKeys.customerId);
    return raw?.replaceAll('"', '');
  }

  Future<String?> _deviceId() async {
    final raw = await _storage.read(StorageKeys.deviceId);
    return raw?.replaceAll('"', '');
  }

  Future<String?> _userType() async {
    final raw = await _storage.read(StorageKeys.userType);
    return raw?.replaceAll('"', '');
  }

  Future<HomeBundle> fetchHomeBundle() async {
    final customerId = await _customerId();
    final deviceId = await _deviceId();
    final userType = await _userType();

    final homeFuture = _dio.post(
      ApiEndpoints.homeScreenInformation,
      data: {'Customer_Id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );

    Future<Response<dynamic>>? flagsFuture;
    if (deviceId != null && deviceId.isNotEmpty) {
      // RN ScreenStatus body uses `device_Id` (capital I).
      flagsFuture = _dio.post(
        ApiEndpoints.getScreenCompletionflags,
        data: {'device_Id': deviceId},
        options: Options(contentType: Headers.jsonContentType),
      );
    }

    Future<Response<dynamic>>? creditFuture;
    if (customerId != null && customerId.isNotEmpty) {
      creditFuture = _dio.post(
        ApiEndpoints.getCreditDecisionInformation,
        data: {'customer_id': customerId},
        options: Options(contentType: Headers.jsonContentType),
      );
    }

    final homeRes = await homeFuture;
    final homeData = homeRes.data;
    final homeMap = homeData is Map<String, dynamic>
        ? homeData
        : homeData is Map
            ? Map<String, dynamic>.from(homeData)
            : <String, dynamic>{};

    var flags = const ScreenCompletionFlags();
    if (flagsFuture != null) {
      try {
        final flagsRes = await flagsFuture;
        final raw = flagsRes.data;
        final list = raw is List
            ? raw
            : (raw is Map && raw['data'] is List)
                ? raw['data'] as List
                : const [];
        flags = ScreenCompletionFlags.fromScreenList(list);
      } catch (_) {
        // Home still usable without flags.
      }
    }

    CreditDecisionSummary? creditDecision;
    if (creditFuture != null) {
      try {
        final creditRes = await creditFuture;
        final raw = creditRes.data;
        Map<String, dynamic>? row;
        if (raw is List && raw.isNotEmpty && raw.first is Map) {
          row = Map<String, dynamic>.from(raw.first as Map);
        } else if (raw is Map) {
          final data = raw['data'];
          if (data is List && data.isNotEmpty && data.first is Map) {
            row = Map<String, dynamic>.from(data.first as Map);
          } else {
            row = Map<String, dynamic>.from(raw);
          }
        }
        if (row != null) {
          final status = row['status']?.toString();
          // API uses HTTP 200 with body {status:403,msg:...} when no offer —
          // do not treat that as a credit decision row.
          if (status != '403' && row['error'] == null) {
            creditDecision = CreditDecisionSummary.fromJson(row);
          }
        }
      } catch (_) {
        // Offer card optional if CD info fails.
      }
    }

    return HomeBundle(
      home: HomeSnapshot.fromJson(homeMap),
      flags: flags,
      creditDecision: creditDecision,
      userType: userType,
    );
  }

  /// Lightweight home call — contract id + loan account only (no CD / flags).
  Future<({String? contractId, Map<String, dynamic>? loanAccount})>
      fetchContractHint() async {
    final customerId = await _customerId();
    final homeRes = await _dio.post(
      ApiEndpoints.homeScreenInformation,
      data: {'Customer_Id': customerId},
      options: Options(contentType: Headers.jsonContentType),
    );
    final homeData = homeRes.data;
    final homeMap = homeData is Map<String, dynamic>
        ? homeData
        : homeData is Map
            ? Map<String, dynamic>.from(homeData)
            : <String, dynamic>{};
    final home = HomeSnapshot.fromJson(homeMap);
    return (contractId: home.contractId, loanAccount: home.loanAccount);
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});

/// Bumped before navigating to Home after credit decision / unlock so the
/// shell IndexedStack reloads instead of showing a stale blank card.
final homeRefreshTickProvider = StateProvider<int>((ref) => 0);
