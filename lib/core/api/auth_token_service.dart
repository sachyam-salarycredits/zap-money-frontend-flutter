import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:uuid/uuid.dart';

import '../constants/api_endpoints.dart';
import '../constants/app_config.dart';
import '../constants/storage_keys.dart';
import '../storage/session_storage.dart';
import 'api_lock_service.dart';

/// Token lifecycle matching RN `verifyAndGetToken` / guest / refresh.
class AuthTokenService {
  AuthTokenService({
    required SessionStorage storage,
    required ApiLockService apiLock,
    required Dio oauthDio,
    required Future<String> Function() deviceIdProvider,
  })  : _storage = storage,
        _apiLock = apiLock,
        _oauthDio = oauthDio,
        _deviceIdProvider = deviceIdProvider;

  final SessionStorage _storage;
  final ApiLockService _apiLock;
  final Dio _oauthDio;
  final Future<String> Function() _deviceIdProvider;
  final _uuid = const Uuid();

  Future<String?> verifyAndGetToken() async {
    var authTokenRaw = await _storage.read(StorageKeys.storageToken);
    var normalAuthTokenRaw = await _storage.read(StorageKeys.normalToken);
    final loginTokenRaw = await _storage.read(StorageKeys.token);

    if ((authTokenRaw == null || authTokenRaw.isEmpty) &&
        loginTokenRaw != null &&
        loginTokenRaw.isNotEmpty) {
      try {
        final loginAccessToken = _decodeLoginToken(loginTokenRaw);
        if (loginAccessToken != null) {
          await persistLoginAccessToken(loginAccessToken);
          authTokenRaw = await _storage.read(StorageKeys.storageToken);
        }
      } catch (_) {}
    }

    if ((authTokenRaw == null || authTokenRaw.isEmpty) &&
        (normalAuthTokenRaw == null || normalAuthTokenRaw.isEmpty)) {
      return getGuestTokenFromService();
    }

    if (authTokenRaw != null && authTokenRaw.isNotEmpty) {
      final decoded = await _storage.readJson(StorageKeys.storageToken);
      if (decoded == null) {
        return getGuestTokenFromService();
      }
      final expiry = decoded['expireyTime'] as String?;
      final isValid = expiry != null && DateTime.parse(expiry).isAfter(DateTime.now());
      if (!isValid) {
        final refresh = decoded['refreshToken'] as String?;
        if (refresh != null && refresh.isNotEmpty) {
          final refreshed = await getRefreshTokenFromService(refresh);
          if (refreshed != null) return refreshed;
        }
        final stale = decoded['token'] as String?;
        if (stale != null && stale.isNotEmpty) return stale;
        return _decodeLoginToken(loginTokenRaw);
      }
      return decoded['token'] as String?;
    }

    if (normalAuthTokenRaw != null && normalAuthTokenRaw.isNotEmpty) {
      return getGuestTokenFromAsync();
    }
    return null;
  }

  Future<void> persistLoginAccessToken(
    String accessToken, {
    String? refreshToken,
  }) async {
    // RN: AsyncStorage.setItem(token, JSON.stringify(accessToken))
    await _storage.write(StorageKeys.token, jsonEncode(accessToken));

    var expireyTime = DateTime.now().add(const Duration(days: 1)).toIso8601String();
    try {
      final decoded = JwtDecoder.decode(accessToken);
      final life = decoded['access_token_life_time'];
      if (life is num) {
        expireyTime = DateTime.now()
            .add(Duration(seconds: life.toInt() - 20))
            .toIso8601String();
      } else if (decoded['exp'] is num) {
        expireyTime = DateTime.fromMillisecondsSinceEpoch(
          (decoded['exp'] as num).toInt() * 1000,
        ).toIso8601String();
      }
    } catch (_) {}

    await _storage.writeJson(StorageKeys.storageToken, {
      'token': accessToken,
      'refreshToken': refreshToken,
      'expireyTime': expireyTime,
    });
  }

  /// RN does `JSON.stringify(access_token)` so storage may be `"eyJ..."` or raw.
  String? _decodeLoginToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final trimmed = raw.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        return trimmed.substring(1, trimmed.length - 1);
      }
      // jsonDecode of a JSON string
      if (trimmed.startsWith('"')) {
        return trimmed.replaceAll('"', '');
      }
      return trimmed;
    } catch (_) {
      return raw;
    }
  }

  Future<String?> getGuestTokenFromService() async {
    final lockToken = _uuid.v4();
    _apiLock.lock(lockToken);
    try {
      final deviceId = await _deviceIdProvider();
      final response = await _oauthDio.post(
        ApiEndpoints.generateRefreshToken,
        data: jsonEncode({
          'client_id': AppConfig.oauthClientId,
          'client_secrect': AppConfig.oauthClientSecret,
          'device_id': deviceId,
          'grant_type': 'client_credentials',
        }),
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'lockToken': lockToken},
        ),
      );
      if (response.statusCode == 200) {
        final accessToken = response.data['access_token'] as String;
        final decoded = JwtDecoder.decode(accessToken);
        final life = (decoded['access_token_life_time'] as num?)?.toInt() ?? 3600;
        await _storage.writeJson(StorageKeys.normalToken, {
          'token': accessToken,
          'expireyTime': DateTime.now()
              .add(Duration(seconds: life - 20))
              .toIso8601String(),
        });
        return accessToken;
      }
    } catch (_) {
      // RN continues without guest token when UAT security is unreachable.
    } finally {
      _apiLock.releaseLock(lockToken);
    }
    return null;
  }

  Future<String?> getRefreshTokenFromService(String refreshToken) async {
    final lockToken = _uuid.v4();
    _apiLock.lock(lockToken);
    try {
      final deviceId = await _deviceIdProvider();
      final customerId = await _storage.read(StorageKeys.customerId);
      final response = await _oauthDio.post(
        ApiEndpoints.generateRefreshToken,
        data: jsonEncode({
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
          'client_id': AppConfig.oauthClientId,
          'client_secrect': AppConfig.oauthClientSecret,
          'device_id': deviceId,
          'user_id': customerId,
        }),
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'lockToken': lockToken},
        ),
      );
      if (response.statusCode == 200) {
        final accessToken = response.data['access_token'] as String;
        final newRefresh = response.data['refresh_token'] as String?;
        final decoded = JwtDecoder.decode(accessToken);
        final life = (decoded['access_token_life_time'] as num?)?.toInt() ?? 3600;
        await _storage.writeJson(StorageKeys.storageToken, {
          'token': accessToken,
          'refreshToken': newRefresh,
          'expireyTime': DateTime.now()
              .add(Duration(seconds: life - 20))
              .toIso8601String(),
        });
        return accessToken;
      }
    } catch (_) {
    } finally {
      _apiLock.releaseLock(lockToken);
    }
    return null;
  }

  Future<String?> getGuestTokenFromAsync() async {
    final decoded = await _storage.readJson(StorageKeys.normalToken);
    if (decoded == null) return getGuestTokenFromService();
    final expiry = decoded['expireyTime'] as String?;
    final isValid = expiry != null && DateTime.parse(expiry).isAfter(DateTime.now());
    if (!isValid) return getGuestTokenFromService();
    return decoded['token'] as String?;
  }
}
