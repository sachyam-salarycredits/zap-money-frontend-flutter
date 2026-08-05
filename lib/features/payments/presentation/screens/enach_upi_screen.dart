import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../data/enach_repository.dart';

class EnachUpiScreen extends ConsumerStatefulWidget {
  const EnachUpiScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<EnachUpiScreen> createState() => _EnachUpiScreenState();
}

class _EnachUpiScreenState extends ConsumerState<EnachUpiScreen> {
  final _vpa = TextEditingController();
  String? _status;

  @override
  void dispose() {
    _vpa.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vpa = _vpa.text.trim();
    if (!vpa.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid UPI ID')),
      );
      return;
    }
    ref.read(globalLoadingProvider.notifier).state = true;
    setState(() => _status = 'Validating UPI…');
    try {
      final home = await ref.read(homeRepositoryProvider).fetchHomeBundle();
      final contractId = home.home.contractId ?? '';
      final amount = widget.args?['amount']?.toString() ??
          home.home.emiAmount?.toString() ??
          '0';
      final repo = ref.read(enachRepositoryProvider);
      await repo.validateVpa(vpa: vpa, contractId: contractId);

      final now = DateTime.now();
      final fmt = DateFormat('yyyy-MM-dd');
      setState(() => _status = 'Creating mandate…');
      await repo.createUpiMandate(
        vpa: vpa,
        amount: amount,
        contractId: contractId,
        validityStart: fmt.format(now),
        validityEnd: fmt.format(now.add(const Duration(days: 365 * 5))),
      );

      setState(() => _status = 'Waiting for approval…');
      var ok = false;
      for (var i = 0; i < 15; i++) {
        ok = await repo.isUpiMandateApproved(contractId);
        if (ok) break;
        await Future.delayed(const Duration(seconds: 2));
      }
      if (!mounted) return;
      if (ok) {
        try {
          await ref.read(screenStatusServiceProvider).completeEnach();
        } catch (_) {}
        ref.read(homeRefreshTickProvider.notifier).state++;
        context.go(AppRoutes.home);
      } else {
        setState(() => _status = 'Mandate not approved yet. You can retry from Home.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'UPI mandate failed. Try netbanking instead.');
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'UPI eNACH',
      subtitle: 'Authorize EMI collection via your UPI ID.',
      bottom: ZapSubmitButton(title: 'Authorize', onPressed: _submit),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _vpa,
            style: AppTypography.body(size: 16),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'yourname@upi',
              hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!, style: AppTypography.body(size: 14, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
