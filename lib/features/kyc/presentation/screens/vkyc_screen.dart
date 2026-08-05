import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/kyc_repository.dart';

class VkycScreen extends ConsumerStatefulWidget {
  const VkycScreen({super.key});

  @override
  ConsumerState<VkycScreen> createState() => _VkycScreenState();
}

class _VkycScreenState extends ConsumerState<VkycScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    try {
      final passed = await ref.read(kycRepositoryProvider).isVkycPassed();
      if (passed && mounted) {
        await ref.read(screenStatusServiceProvider).completeVkyc();
        if (mounted) context.go(AppRoutes.home);
      }
    } catch (_) {}
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final repo = ref.read(kycRepositoryProvider);
      final info = await repo.getCustomerInfo();
      final first = info?['first_name']?.toString() ?? '';
      final last = info?['last_name']?.toString() ?? '';
      final panName = '$first $last'.trim();
      final dobRaw = info?['dob']?.toString();
      var panDob = '';
      if (dobRaw != null && dobRaw.isNotEmpty) {
        final parsed = DateTime.tryParse(dobRaw);
        panDob = parsed != null
            ? DateFormat('dd/MM/yyyy').format(parsed)
            : dobRaw;
      }
      final url = await repo.createVkycLink(panDob: panDob, panName: panName);
      if (url == null || url.isEmpty) {
        setState(() => _message = 'Unable to create Video KYC link');
        return;
      }
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        setState(() => _message = 'Could not open KYC browser');
      } else {
        setState(() =>
            _message = 'Complete Video KYC in the browser, then return here.');
      }
    } catch (_) {
      setState(() => _message = 'Could not start Video KYC');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Video KYC',
      subtitle: 'Verify your identity via a short video call / capture flow.',
      bottom: ZapSubmitButton(
        title: _busy ? 'Starting…' : 'Start Video KYC',
        onPressed: _busy ? null : _start,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Make sure you are in a well-lit space and have your PAN ready.',
            style: AppTypography.body(size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          ZapSubmitButton(title: 'I’ve finished — check status', onPressed: _checkStatus),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: AppTypography.body(size: 14)),
          ],
        ],
      ),
    );
  }
}
