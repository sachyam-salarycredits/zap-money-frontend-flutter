import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_lock_service.dart';
import 'auth_token_service.dart';

typedef UnauthorizedHandler = void Function();

/// Dio client matching RN `httpClient` / `httpClientV1` header contract.
/// Auth header name is `token` (not Bearer), unless `clearHeader` / `lockToken` extras.
///
/// Important: do NOT set `Content-Type: application/json;charset=utf-8;` via the
/// default headers map — Dio then may skip JSON-encoding Map bodies, and Django
/// receives an empty body (`JSON parse error - Expecting value`).
class DioClient {
  DioClient({
    required AuthTokenService tokenService,
    required ApiLockService apiLock,
    UnauthorizedHandler? onUnauthorized,
  })  : _tokenService = tokenService,
        _apiLock = apiLock,
        _onUnauthorized = onUnauthorized {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          // Ngrok free blocks Dio's default `Dart/...` UA; RN OkHttp passes.
          'User-Agent': 'okhttp/4.12.0',
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  late final Dio _dio;
  final AuthTokenService _tokenService;
  final ApiLockService _apiLock;
  final UnauthorizedHandler? _onUnauthorized;

  Dio get dio => _dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final lockToken = options.extra['lockToken'] as String?;
    if (_apiLock.isLocked(requestLockToken: lockToken)) {
      await _apiLock.waitTillUnlocked();
    }

    _ensureJsonBody(options);
    _ensureNgrokHeaders(options);

    if (lockToken != null) {
      options.extra.remove('lockToken');
      handler.next(options);
      return;
    }

    if (options.extra['clearHeader'] == true) {
      options.contentType = Headers.jsonContentType;
      handler.next(options);
      return;
    }

    final token = await _tokenService.verifyAndGetToken();
    if (token != null) {
      if (options.extra['useBearer'] == true) {
        // RN httpClientV1 DigiLocker calls send BOTH Authorization Bearer and `token`.
        options.headers['Authorization'] = 'Bearer $token';
        options.headers['token'] = token;
      } else {
        options.headers['token'] = token;
      }
    }
    if (kDebugMode) {
      debugPrint('Dio → ${options.method} ${options.uri}');
      debugPrint('Dio body → ${options.data}');
    }
    handler.next(options);
  }

  /// ngrok-free serves an interstitial / blocks non-browser clients unless
  /// this header is present — Register_api never reaches Django otherwise.
  void _ensureNgrokHeaders(RequestOptions options) {
    final host = options.uri.host;
    if (!host.contains('ngrok')) return;
    options.headers.putIfAbsent(
      'ngrok-skip-browser-warning',
      () => 'true',
    );
    options.headers.putIfAbsent('User-Agent', () => 'okhttp/4.12.0');
  }

  /// Guarantees Map/List POST bodies are real JSON bytes for DRF.
  /// FormData must keep multipart + boundary — clear BaseOptions JSON type.
  void _ensureJsonBody(RequestOptions options) {
    final data = options.data;
    if (data is FormData) {
      options.contentType = null;
      options.headers.remove(Headers.contentTypeHeader);
      return;
    }
    if (data == null || data is String) {
      if (data is String && data.isNotEmpty) {
        options.contentType = Headers.jsonContentType;
      }
      return;
    }
    if (data is Map || data is List) {
      options.data = jsonEncode(data);
      options.contentType = Headers.jsonContentType;
      options.headers[Headers.contentTypeHeader] = Headers.jsonContentType;
    }
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final status = error.response?.statusCode;
    if (status == 401) {
      final url = error.requestOptions.uri.toString();
      if (!url.contains('validate-device') && !url.contains('Register_api')) {
        _onUnauthorized?.call();
      }
    }
    handler.next(error);
  }
}
