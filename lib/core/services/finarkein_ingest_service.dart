import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../api/dio_client.dart';
import '../constants/api_endpoints.dart';
import '../constants/storage_keys.dart';
import '../storage/session_storage.dart';
import 'screen_status_service.dart';

/// Polls Finarkein run status/sync after AA consent so the funnel can continue
/// (residence address) while ingest finishes in the background.
class FinarkeinIngestService {
  FinarkeinIngestService({
    required Dio dio,
    required SessionStorage storage,
    required ScreenStatusService screenStatus,
  })  : _dio = dio,
        _storage = storage,
        _screenStatus = screenStatus;

  final Dio _dio;
  final SessionStorage _storage;
  final ScreenStatusService _screenStatus;

  String? _activeRequestId;
  var _loopRunning = false;

  Future<void> persistRequestId(String requestId) async {
    await _storage.write(StorageKeys.finarkeinRequestId, requestId);
  }

  Future<String?> readRequestId() async {
    final raw = await _storage.read(StorageKeys.finarkeinRequestId);
    return raw?.replaceAll('"', '');
  }

  /// Fire-and-forget polling until READY / FAILED (survives leaving FinbitScreen).
  void startBackground(String requestId) {
    if (requestId.isEmpty) return;
    _activeRequestId = requestId;
    unawaited(persistRequestId(requestId));
    unawaited(_runLoop(requestId));
  }

  /// True when Finarkein reports consent approved (ACTIVE) or run already past
  /// consent (READY / in-flight ingest). Mock request ids always pass.
  ///
  /// Used before leaving Bank validation → Residence so kill/abandon mid-OTP
  /// cannot advance the funnel.
  Future<bool> waitUntilConsentApproved({
    required String requestId,
    Duration maxWait = const Duration(seconds: 45),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return false;
    if (id.toLowerCase().startsWith('mock-')) return true;

    final deadline = DateTime.now().add(maxWait);
    while (true) {
      final payload = await _refreshStatus(id);
      if (_payloadHasApprovedConsent(payload)) return true;
      final lifecycle = payload?['lifecycle']?.toString().toUpperCase();
      if (lifecycle == 'FAILED') return false;
      if (!DateTime.now().isBefore(deadline)) break;
      await Future<void>.delayed(interval);
    }
    final last = await _refreshStatus(id);
    return _payloadHasApprovedConsent(last);
  }

  /// Used on Waiting before credit decision — wait up to [maxWait] for READY.
  Future<bool> waitUntilReady({
    String? requestId,
    Duration maxWait = const Duration(minutes: 2),
    Duration interval = const Duration(seconds: 6),
  }) async {
    final id = (requestId ?? await readRequestId())?.trim();
    if (id == null || id.isEmpty) return false;

    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      final lifecycle = await _syncOnce(id);
      if (lifecycle == 'READY') {
        await _onReady();
        return true;
      }
      if (lifecycle == 'FAILED') return false;
      await Future<void>.delayed(interval);
    }
    // Last attempt
    final lifecycle = await _syncOnce(id);
    if (lifecycle == 'READY') {
      await _onReady();
      return true;
    }
    return false;
  }

  Future<void> _runLoop(String requestId) async {
    if (_loopRunning && _activeRequestId == requestId) return;
    _loopRunning = true;
    try {
      // ~40 * 8s ≈ Celery-style bound without blocking the UI.
      for (var i = 0; i < 40; i++) {
        if (_activeRequestId != requestId) return;
        final lifecycle = await _syncOnce(requestId);
        if (lifecycle == 'READY') {
          await _onReady();
          return;
        }
        if (lifecycle == 'FAILED') return;
        await Future<void>.delayed(const Duration(seconds: 8));
      }
    } finally {
      if (_activeRequestId == requestId) {
        _loopRunning = false;
      }
    }
  }

  Map? _unwrap(dynamic root) {
    if (root is! Map) return null;
    final resp = root['response'];
    return resp is Map ? resp : root;
  }

  /// Consent ACTIVE, or lifecycle already past AA approval.
  bool _payloadHasApprovedConsent(Map? payload) {
    if (payload == null) return false;
    final lifecycle = payload['lifecycle']?.toString().toUpperCase();
    if (lifecycle == 'READY' ||
        lifecycle == 'FETCHED' ||
        lifecycle == 'PROJECTING' ||
        lifecycle == 'PARTIAL') {
      return true;
    }
    final consents = payload['consents'];
    if (consents is! List) return false;
    for (final item in consents) {
      if (item is! Map) continue;
      final status =
          (item['consent_status'] ?? item['consentStatus'] ?? '')
              .toString()
              .toUpperCase();
      if (status == 'ACTIVE') return true;
    }
    return false;
  }

  Future<Map?> _getStatus(String requestId) async {
    try {
      final statusRes = await _dio.get(
        ApiEndpoints.finarkeinRunStatus(requestId),
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return _unwrap(statusRes.data);
    } catch (_) {
      return null;
    }
  }

  /// GET cached status; POST sync until lifecycle is READY/FAILED.
  ///
  /// Do **not** stop syncing just because consent is ACTIVE — ACTIVE only means
  /// the user approved AA; result ingest still needs sync to reach READY.
  Future<Map?> _refreshStatus(String requestId) async {
    final statusPayload = await _getStatus(requestId);
    final lifecycle = statusPayload?['lifecycle']?.toString().toUpperCase();
    if (lifecycle == 'READY' || lifecycle == 'FAILED') return statusPayload;

    try {
      final syncRes = await _dio.post(
        ApiEndpoints.finarkeinRunSync(requestId),
        data: {},
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      return _unwrap(syncRes.data) ?? statusPayload;
    } catch (_) {
      return statusPayload;
    }
  }

  Future<String?> _syncOnce(String requestId) async {
    final payload = await _refreshStatus(requestId);
    return payload?['lifecycle']?.toString().toUpperCase();
  }

  Future<void> _onReady() async {
    try {
      await _screenStatus.completeBank();
      await _screenStatus.completeFinbit();
    } catch (_) {
      // Flags may already be set by the backend READY path.
    }
  }
}

final finarkeinIngestServiceProvider = Provider<FinarkeinIngestService>((ref) {
  return FinarkeinIngestService(
    dio: ref.watch(dioClientProvider).dio,
    storage: ref.watch(sessionStorageProvider),
    screenStatus: ref.watch(screenStatusServiceProvider),
  );
});
