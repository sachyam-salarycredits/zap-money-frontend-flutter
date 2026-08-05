import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_lock_service.dart';
import '../../../../core/api/auth_token_service.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/storage/session_storage.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage();
});

final apiLockProvider = Provider<ApiLockService>((ref) => ApiLockService());

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService(ref.watch(sessionStorageProvider));
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final unauthorizedSignalProvider = StateProvider<int>((ref) => 0);

final authTokenServiceProvider = Provider<AuthTokenService>((ref) {
  final oauthDio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  return AuthTokenService(
    storage: ref.watch(sessionStorageProvider),
    apiLock: ref.watch(apiLockProvider),
    oauthDio: oauthDio,
    deviceIdProvider: () => ref.read(deviceIdServiceProvider).getDeviceId(),
  );
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    tokenService: ref.watch(authTokenServiceProvider),
    apiLock: ref.watch(apiLockProvider),
    onUnauthorized: () {
      ref.read(unauthorizedSignalProvider.notifier).state++;
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(dio),
    storage: ref.watch(sessionStorageProvider),
    tokenService: ref.watch(authTokenServiceProvider),
    deviceIdService: ref.watch(deviceIdServiceProvider),
  );
});

final sendOtpUseCaseProvider = Provider((ref) {
  return SendOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider((ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

final resolvePostLoginRouteUseCaseProvider = Provider((ref) {
  return ResolvePostLoginRouteUseCase(ref.watch(authRepositoryProvider));
});

final globalLoadingProvider = StateProvider<bool>((ref) => false);
