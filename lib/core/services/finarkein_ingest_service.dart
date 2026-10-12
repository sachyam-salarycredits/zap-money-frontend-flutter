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

  /// Remember the consent run. LOS downloads the report; the app does not.
  void startBackground(String requestId) {
    if (requestId.isEmpty) return;
    _activeRequestId = requestId;
    unawaited(persistRequestId(requestId));
  }

  /// True when every consent slot is ACTIVE.
  ///
  /// Used before leaving Bank validation → Residence so kill/abandon mid-OTP
  /// cannot advance the funnel. The bank report is not required.
  Future<bool> waitUntilConsentApproved({
    required String requestId,
    Duration maxWait = const Duration(seconds: 45),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return false;
    await _enqueuePoll(id);

    final deadline = DateTime.now().add(maxWait);
    while (true) {
      final payload = await _getStatus(id);
      if (_payloadHasApprovedConsent(payload)) return true;
      final lifecycle = payload?['lifecycle']?.toString().toUpperCase();
      if (lifecycle == 'FAILED') return false;
      if (!DateTime.now().isBefore(deadline)) break;
      await Future<void>.delayed(interval);
    }
    final last = await _getStatus(id);
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

  /// Every returned consent must be ACTIVE. One approved slot is not enough.
  bool _payloadHasApprovedConsent(Map? payload) {
    if (payload == null) return false;
    final consents = payload['consents'];
    if (consents is! List || consents.isEmpty) return false;
    for (final item in consents) {
      if (item is! Map) return false;
      final status =
          (item['consent_status'] ?? item['consentStatus'] ?? '')
              .toString()
              .toUpperCase();
      if (status != 'ACTIVE') return false;
    }
    return true;
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

  /// Ask Celery to poll Finarkein. The request returns the saved status.
  Future<void> _enqueuePoll(String requestId) async {
    try {
      await _dio.post(
        ApiEndpoints.finarkeinRunSync(requestId),
        data: {},
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
    } catch (_) {}
  }

  Future<String?> _syncOnce(String requestId) async {
    final payload = await _getStatus(requestId);
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
