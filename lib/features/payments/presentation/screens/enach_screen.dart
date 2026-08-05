import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../data/enach_repository.dart';
import 'mandate_webview_screen.dart';

class EnachScreen extends ConsumerStatefulWidget {
  const EnachScreen({super.key});

  @override
  ConsumerState<EnachScreen> createState() => _EnachScreenState();
}

class _EnachScreenState extends ConsumerState<EnachScreen> {
  bool _loading = true;
  bool _upiEnabled = false;
  String? _error;
  String _emiDay = '5';
  String _method = '2'; // 1=UPI, 2=netbanking, 3=debitcard
  Map<String, dynamic>? _enachInfo;

  static const _emiDays = ['1', '3', '5', '7'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(enachRepositoryProvider);
      final info = await repo.getEnachInformation();
      final ensured = await repo.ensureEnachAmountOnBank(enachInfo: info);
      final upi = await repo.isUpiEnabled();
      if (mounted) {
        setState(() {
          _enachInfo = {
            ...?info,
            ...?ensured,
          };
          _upiEnabled = upi;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load eNACH details';
        });
      }
    }
  }

  String get _authMode => _method == '3' ? 'debitcard' : 'netbanking';

  Future<void> _proceed() async {
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final repo = ref.read(enachRepositoryProvider);
      await repo.storeEmiDate(_emiDay);

      // Cashfree reads Bank_Account_Information.Enach_Amount — ensure it is set.
      final ensured = await repo.ensureEnachAmountOnBank(enachInfo: _enachInfo);
      final amount = ensured?['enach_amount'] ?? _enachInfo?['enach_amount'];
      if (amount == null ||
          (double.tryParse(amount.toString()) ?? 0) <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'eNACH amount is missing on your bank account. '
                'Please reopen the app after your offer is confirmed, or contact support.',
              ),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _enachInfo = {...?_enachInfo, ...?ensured};
        });
      }

      if (_method == '1') {
        if (!mounted) return;
        context.push(AppRoutes.enachUpi, extra: {
          'amount': amount.toString(),
          'account': (_enachInfo?['bank_account_number'] ??
                  ensured?['bank_account_number'])
              ?.toString() ??
              '',
        });
        return;
      }

      final created = await repo.createSource(authMode: _authMode);
      final url = created?['mandate_url']?.toString();
      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                created?['msg']?.toString() ?? 'Unable to start eNACH',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MandateWebViewScreen(
            initialUrl: url,
            onSuccess: () async {
              Navigator.of(context).pop();
              await _pollAndGoHome();
            },
            onClose: () => context.go(AppRoutes.home),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final msg = e is DioException && e.response?.data is Map
            ? (e.response!.data['msg'] ?? e.response!.data['message'])
                ?.toString()
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Could not start eNACH')),
        );
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _pollAndGoHome() async {
    final repo = ref.read(enachRepositoryProvider);
    for (var i = 0; i < 6; i++) {
      try {
        if (await repo.checkSourceStatus()) break;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    try {
      await ref.read(screenStatusServiceProvider).completeEnach();
    } catch (_) {}
    ref.read(homeRefreshTickProvider.notifier).state++;
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final amount = _enachInfo?['enach_amount'];
    final account = _enachInfo?['bank_account_number'];
    final ifsc = _enachInfo?['ifsc_code'];

    return FunnelScaffold(
      title: 'Set up eNACH',
      subtitle: 'Authorize automatic EMI collection for your loan.',
      bottom: _loading
          ? null
          : ZapSubmitButton(title: 'Continue', onPressed: _proceed),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentMint),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Text(_error!, style: AppTypography.body(size: 14)),
                Text(
                  'EMI amount: ${amount ?? '—'}',
                  style: AppTypography.headline(size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Account: ${account ?? '—'}  ·  IFSC: ${ifsc ?? '—'}',
                  style: AppTypography.body(size: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                Text('Preferred EMI day', style: AppTypography.headline(size: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in _emiDays)
                      ChoiceChip(
                        label: Text(d),
                        selected: _emiDay == d,
                        onSelected: (_) => setState(() => _emiDay = d),
                        selectedColor: AppColors.accentMint.withValues(alpha: 0.3),
                        labelStyle: AppTypography.body(size: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Payment method', style: AppTypography.headline(size: 16)),
                const SizedBox(height: 8),
                if (_upiEnabled)
                  RadioListTile<String>(
                    value: '1',
                    groupValue: _method,
                    onChanged: (v) => setState(() => _method = v!),
                    title: Text('UPI', style: AppTypography.body(size: 15)),
                    activeColor: AppColors.accentMint,
                  ),
                RadioListTile<String>(
                  value: '2',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: Text('Net banking', style: AppTypography.body(size: 15)),
                  activeColor: AppColors.accentMint,
                ),
                RadioListTile<String>(
                  value: '3',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: Text('Debit card', style: AppTypography.body(size: 15)),
                  activeColor: AppColors.accentMint,
                ),
              ],
            ),
    );
  }
}
