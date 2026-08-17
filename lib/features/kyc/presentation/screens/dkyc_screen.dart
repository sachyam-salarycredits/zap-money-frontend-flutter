import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../data/kyc_repository.dart';

class DkycScreen extends ConsumerStatefulWidget {
  const DkycScreen({super.key});

  @override
  ConsumerState<DkycScreen> createState() => _DkycScreenState();
}

class _DkycScreenState extends ConsumerState<DkycScreen> {
  bool _starting = false;
  String? _message;
  String? _webUrl;
  String? _verificationId;
  Timer? _poller;
  WebViewController? _controller;
  var _completing = false;

  static const _failStatuses = {
    'CONSENT_DENIED',
    'EXPIRED',
    'FAILED',
    'INVALID',
  };

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _message = null;
    });
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final created = await ref.read(kycRepositoryProvider).digilockerCreate();
      if (kDebugMode) {
        debugPrint('digilockerCreate → $created');
      }

      // Soft error from backend (often HTTP 200 + status/msg, no url).
      final createMsg = KycRepository.extractErrorMessage(created);
      final createStatus = created?['status'];
      if (createMsg != null &&
          created?['verificationId'] == null &&
          created?['url'] == null) {
        _showError(createMsg);
        return;
      }
      if (createStatus == 400 ||
          createStatus == 403 ||
          createStatus == 503 ||
          createStatus == '400' ||
          createStatus == '403' ||
          createStatus == '503') {
        _showError(
          createMsg ?? 'Unable to start DigiLocker. Please try again.',
        );
        return;
      }

      final url = created?['url']?.toString();
      final verificationId = created?['verificationId']?.toString();
      final status = (created?['digilockerStatus']?.toString() ?? '')
          .toUpperCase();

      // Match RN: AUTHENTICATED session can complete without opening WebView.
      if (verificationId != null && status == 'AUTHENTICATED') {
        _verificationId = verificationId;
        await _finish();
        return;
      }
      if (url == null ||
          url.isEmpty ||
          url == 'about:blank' ||
          verificationId == null) {
        _showError(
          createMsg ?? 'Unable to start DigiLocker. Please try again.',
        );
        return;
      }
      _verificationId = verificationId;
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(url));
      setState(() => _webUrl = url);
      _startPolling(verificationId);
    } catch (e) {
      if (kDebugMode) debugPrint('digilockerCreate error → $e');
      _showError('Unable to start DigiLocker. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
  }

  void _startPolling(String verificationId) {
    _poller?.cancel();
    final started = DateTime.now();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (DateTime.now().difference(started) > const Duration(minutes: 10)) {
        _poller?.cancel();
        if (mounted) {
          setState(() => _webUrl = null);
          _showError('DigiLocker timed out. Please try again.');
        }
        return;
      }
      try {
        final statusRes = await ref
            .read(kycRepositoryProvider)
            .digilockerPoll(verificationId: verificationId);
        final status = (statusRes?['digilockerStatus']?.toString() ?? '')
            .toUpperCase();
        if (status == 'AUTHENTICATED') {
          _poller?.cancel();
          if (mounted) setState(() => _webUrl = null);
          await _finish();
        } else if (_failStatuses.contains(status)) {
          _poller?.cancel();
          if (mounted) setState(() => _webUrl = null);
          const messages = {
            'CONSENT_DENIED':
                'You declined DigiLocker access. Please try again.',
            'EXPIRED': 'DigiLocker session expired. Please try again.',
            'FAILED': 'DigiLocker verification failed. Please try again.',
            'INVALID': 'DigiLocker session is invalid. Please try again.',
          };
          _showError(
            messages[status] ??
                'DigiLocker verification could not be completed.',
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _finish() async {
    if (_completing) return;
    _completing = true;
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final repo = ref.read(kycRepositoryProvider);
      final verificationId = _verificationId;
      if (verificationId == null || verificationId.isEmpty) {
        _showError('Missing DigiLocker session. Please try again.');
        return;
      }

      final completed = await repo.digilockerCompleteWithRetry(
        verificationId: verificationId,
      );
      final name = KycRepository.extractAadhaarName(completed);
      if (name == null || name.isEmpty) {
        final backendMsg = KycRepository.extractErrorMessage(completed);
        _showError(
          backendMsg ?? 'Aadhaar details not available. Please try again.',
        );
        return;
      }

      final profile = await repo.getCustomerInfo();
      final aadhaar =
          profile?['aadhaar_number']?.toString() ??
          profile?['aadhar_number']?.toString() ??
          '';
      final ok = await repo.uploadDkycFrontend(
        customerName: name,
        aadhaarNumber: aadhaar,
      );
      if (!ok) {
        _showError('Unable to save DigiLocker KYC. Please try again.');
        return;
      }
      await ref.read(screenStatusServiceProvider).completeVkyc();
      ref.read(homeRefreshTickProvider.notifier).state++;
      // KYC completion is followed by the mandate for the selected contract.
      if (mounted) context.go(AppRoutes.enach);
    } catch (e) {
      if (kDebugMode) debugPrint('digilocker finish error → $e');
      _showError(
        'Unable to complete DigiLocker verification. Please try again.',
      );
    } finally {
      _completing = false;
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_webUrl != null && _controller != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: const Text('DigiLocker'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _poller?.cancel();
              setState(() => _webUrl = null);
            },
          ),
        ),
        body: WebViewWidget(controller: _controller!),
      );
    }

    return FunnelScaffold(
      title: 'Digital KYC',
      subtitle: 'Verify your Aadhaar securely via DigiLocker.',
      bottom: ZapSubmitButton(
        title: _starting ? 'Starting…' : 'Continue with DigiLocker',
        onPressed: _starting ? null : _start,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '1. Your phone number needs to be registered with Aadhaar',
            style: AppTypography.body(size: 14, color: AppColors.muted),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: AppTypography.body(size: 14)),
          ],
        ],
      ),
    );
  }
}
