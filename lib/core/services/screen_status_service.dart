import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../constants/screen_status_flags.dart';
import '../constants/storage_keys.dart';
import '../storage/session_storage.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';

/// Mirrors RN `ScreenStatus.completeStep` → POST `/UpdateScreenStatus`.
class ScreenStatusService {
  ScreenStatusService(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<void> completeStep(String screenName) async {
    final deviceIdRaw = await _storage.read(StorageKeys.deviceId);
    final deviceId = deviceIdRaw?.replaceAll('"', '') ?? '';
    final body = <String, dynamic>{
      'completed': 1,
      'screen_name': screenName,
      if (deviceId.isNotEmpty) 'device_id': deviceId,
    };
    await _dio.post(
      ApiEndpoints.screenCompletionflags,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  Future<void> completePermission() =>
      completeStep(ScreenStatusFlags.permission);

  Future<void> completePersonalInfo() =>
      completeStep(ScreenStatusFlags.personalInfo);

  Future<void> completeEquifax() => completeStep(ScreenStatusFlags.equifax);

  Future<void> completeEmployer() =>
      completeStep(ScreenStatusFlags.employerDetails);

  Future<void> completeCollege() =>
      completeStep(ScreenStatusFlags.collegeDetails);

  Future<void> completeBank() => completeStep(ScreenStatusFlags.bankDetails);

  Future<void> completeBankVerified() =>
      completeStep(ScreenStatusFlags.bankDetailsVerified);

  Future<void> completeFinbit() => completeStep(ScreenStatusFlags.finbit);

  Future<void> completeAddress() =>
      completeStep(ScreenStatusFlags.addressSelection);

  Future<void> completePl() => completeStep(ScreenStatusFlags.pl);

  Future<void> completeDc() => completeStep(ScreenStatusFlags.dc);

  Future<void> completeEnach() => completeStep(ScreenStatusFlags.enach);

  Future<void> completeVkyc() => completeStep(ScreenStatusFlags.vkyc);

  Future<void> completeOcr() => completeStep(ScreenStatusFlags.ocr);
}

final screenStatusServiceProvider = Provider<ScreenStatusService>((ref) {
  return ScreenStatusService(
    ref.watch(dioClientProvider).dio,
    ref.watch(sessionStorageProvider),
  );
});
