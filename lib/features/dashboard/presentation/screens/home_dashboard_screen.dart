import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../data/home_repository.dart';
import '../../domain/home_snapshot.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with WidgetsBindingObserver {
  HomeBundle? _bundle;
  String? _error;
  bool _loading = true;
  final _resolver = const HomeCardResolver();
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await ref.read(homeRepositoryProvider).fetchHomeBundle();
      if (mounted) {
        setState(() {
          _bundle = bundle;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load home. Pull to retry.';
        });
      }
    }
  }

  Future<void> _openKyc() async {
    if (!mounted) return;
    // Product rule: DigiLocker for all user types (no Video KYC).
    context.push(AppRoutes.dkyc);
  }

  void _showCompleteProcessSheet(HomeSnapshot home) {
    final flags = _bundle?.flags;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A0A5C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Complete your process', style: AppTypography.headline(size: 20)),
                const SizedBox(height: 12),
                _StepRow(
                  done: (flags?.ocr == true) || (flags?.vkyc == true),
                  label: 'Digital KYC (DigiLocker)',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openKyc();
                  },
                ),
                _StepRow(
                  done: home.emailVerified,
                  label: 'Activate email',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.emailVerification);
                  },
                ),
                _StepRow(
                  done: flags?.enach == true,
                  label: 'eNACH mandate',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.enach);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeRefreshTickProvider, (previous, next) {
      if (previous != next) {
        _load();
      }
    });

    final home = _bundle?.home;
    final flags = _bundle?.flags;
    final credit = _bundle?.creditDecision;
    final kind = _loading
        ? HomeCardKind.loading
        : _error != null
            ? HomeCardKind.error
            : _resolver.resolve(
                home: home,
                plOrDc: (flags?.pl ?? false) || (flags?.dc ?? false),
                enach: flags?.enach ?? false,
                ocr: flags?.ocr ?? false,
                vkyc: flags?.vkyc ?? false,
                bank: flags?.bankDetails ?? false,
                bankVerified: flags?.bankDetailsVerified ?? false,
                finbit: flags?.finbit ?? false,
                equifax: flags?.equifax ?? false,
                creditStatus: credit?.status,
              );

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentMint,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Home', style: AppTypography.headline(size: 28)),
                        const SizedBox(height: 4),
                        Text(
                          'Your loan overview',
                          style: AppTypography.body(size: 14, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push(AppRoutes.profile),
                    icon: const Icon(Icons.person_outline, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accentMint),
                  ),
                )
              else if (_error != null)
                _HeroCard(
                  title: 'Unable to load',
                  body: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              else
                _buildHero(kind, home),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(HomeCardKind kind, HomeSnapshot? home) {
    final flags = _bundle?.flags;
    final credit = _bundle?.creditDecision;
    final isSalaried =
        (_bundle?.userType ?? '').toLowerCase() == 'salaried';
    final showUnlock =
        isSalaried && flags?.employerDetails != true;

    switch (kind) {
      case HomeCardKind.activeLoan:
        return _HeroCard(
          title: 'Active loan',
          body: [
            if (home?.approvedAmount != null)
              'Amount: ${_currency.format(home!.approvedAmount)}',
            if (home?.emiAmount != null) 'EMI: ${_currency.format(home!.emiAmount)}',
            if (home?.remainingEmi != null) 'Remaining EMIs: ${home!.remainingEmi}',
            if (home?.nextInstallmentDate != null)
              'Next installment: ${home!.nextInstallmentDate}',
            if (home?.contractId != null) 'Contract: ${home!.contractId}',
          ].join('\n'),
          accentAsset: 'assets/images/profile/homecoins.png',
          actionLabel: 'View loan',
          onAction: () => context.push(
            AppRoutes.myLoans,
            extra: home?.contractId,
          ),
          secondaryLabel: 'Pay / Pre-pay',
          onSecondary: () => context.push(AppRoutes.enach),
        );
      case HomeCardKind.funding:
        final isSalaried =
            (_bundle?.userType ?? '').toLowerCase() == 'salaried';
        final loanFunded =
            (home?.peerStage ?? '').toLowerCase() == 'funded';
        return _HeroCard(
          title: 'Disbursal Process',
          body: 'Your loan is in process of funding',
          accentAsset: 'assets/images/profile/homecoins.png',
          timeline: _FundingTimeline(
            kycLabel: isSalaried ? 'Video KYC' : 'Digital KYC',
            loanFunded: loanFunded,
          ),
        );
      case HomeCardKind.cancelled:
        return _HeroCard(
          title: 'Loan cancelled',
          body: 'This application was cancelled and isn’t eligible for re-apply yet.',
          actionLabel: 'Go to profile',
          onAction: () => context.push(AppRoutes.profile),
        );
      case HomeCardKind.cancelReapply:
        return _HeroCard(
          title: 'Ready to re-apply',
          body: 'Your previous application was cancelled. You can start a new loan request.',
          actionLabel: 'Apply again',
          onAction: () => context.go(AppRoutes.waiting),
        );
      case HomeCardKind.completeProcess:
        final kycDone =
            (flags?.ocr == true) || (flags?.vkyc == true);
        final isSalaried =
            (_bundle?.userType ?? '').toLowerCase() == 'salaried';
        return _HeroCard(
          title: 'Disbursal Process',
          body:
              'Your loan will be disbursed once you complete the following steps.',
          timeline: _PendingChecklist(
            kycDone: kycDone,
            kycLabel: isSalaried ? 'Video KYC' : 'Digital KYC',
            emailDone: home?.emailVerified == true,
            enachDone: flags?.enach == true,
          ),
          actionLabel: 'Take action',
          onAction: () => _showCompleteProcessSheet(home!),
        );
      case HomeCardKind.creditOffer:
        final amount = credit?.maxLoanAmount;
        return _HeroCard(
          title: 'Your Credit limit',
          body: amount != null
              ? 'Your credit amount of ${_currency.format(amount)} is ready'
              : 'Your credit amount is ready',
          accentAsset: 'assets/images/profile/homecoins.png',
          actionLabel: 'Withdraw Now',
          onAction: () => context.push(AppRoutes.offer),
          secondaryLabel: showUnlock ? 'Unlock upto ₹50,000' : null,
          onSecondary: showUnlock
              ? () => context.push(
                    AppRoutes.employerDetails,
                    extra: {'isFrom': 'unlockOffer'},
                  )
              : null,
        );
      case HomeCardKind.creditPending:
        return _HeroCard(
          title: 'Waiting for the decision',
          body:
              'We are viewing your application. We try to give you a decision within 24 hours.',
          actionLabel: 'View status',
          onAction: () => context.push(
            AppRoutes.referred,
            extra: {'status': credit?.status},
          ),
        );
      case HomeCardKind.creditRejected:
        return _HeroCard(
          title: 'Loan Application Declined',
          body:
              'Your loan application has been declined. You can re-apply later.',
          actionLabel: 'Back to profile',
          onAction: () => context.push(AppRoutes.profile),
        );
      case HomeCardKind.onboarding:
        return _HeroCard(
          title: 'Finish onboarding',
          body: 'Complete bank verification and residence details to continue.',
          actionLabel: 'Continue',
          onAction: () {
            final f = flags ?? const ScreenCompletionFlags();
            final route = const ScreenStatusResolver().resolve(
              flags: f,
              userType: _bundle?.userType,
            );
            context.go(route);
          },
        );
      case HomeCardKind.idle:
      default:
        return _HeroCard(
          title: 'Welcome to Zap Money',
          body: home?.approvedAmount != null
              ? 'Approved amount ${_currency.format(home!.approvedAmount)}. Continue your journey from offers or profile.'
              : 'Track your application, complete pending steps, and manage your loan from here.',
          accentAsset: 'assets/images/profile/homecoins.png',
          actionLabel: 'View profile',
          onAction: () => context.push(AppRoutes.profile),
        );
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.accentAsset,
    this.steps,
    this.timeline,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? accentAsset;
  final List<_MiniStep>? steps;
  final Widget? timeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1478), Color(0xFF230261)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (accentAsset != null) ...[
            Image.asset(accentAsset!, height: 56, errorBuilder: (_, __, ___) => const SizedBox()),
            const SizedBox(height: 12),
          ],
          Text(title, style: AppTypography.headline(size: 22)),
          const SizedBox(height: 10),
          Text(body, style: AppTypography.body(size: 14, color: AppColors.muted)),
          if (timeline != null) ...[
            const SizedBox(height: 16),
            timeline!,
          ] else if (steps != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (final s in steps!)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: s,
                    ),
                  ),
              ],
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ZapSubmitButton(title: actionLabel!, onPressed: onAction),
          ],
          if (secondaryLabel != null && onSecondary != null)
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: AppTypography.body(size: 14, color: AppColors.accentMint),
              ),
            ),
        ],
      ),
    );
  }
}

/// RN home funding card after KYC + email + eNACH (Disbursal_Bank_Status blank).
class _FundingTimeline extends StatelessWidget {
  const _FundingTimeline({
    required this.kycLabel,
    required this.loanFunded,
  });

  final String kycLabel;
  final bool loanFunded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineStep(done: true, label: kycLabel),
        _TimelineStep(done: true, label: 'Activate E-mail ID'),
        _TimelineStep(done: true, label: 'E-Nach'),
        const SizedBox(height: 4),
        const _InProcessRow(),
        const SizedBox(height: 10),
        _TimelineStep(done: loanFunded, label: 'Loan funded'),
        const _TimelineStep(done: false, label: 'Loan disbursed'),
      ],
    );
  }
}

/// RN pending checklist while any of KYC / email / eNACH is still open.
class _PendingChecklist extends StatelessWidget {
  const _PendingChecklist({
    required this.kycDone,
    required this.kycLabel,
    required this.emailDone,
    required this.enachDone,
  });

  final bool kycDone;
  final String kycLabel;
  final bool emailDone;
  final bool enachDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineStep(done: kycDone, label: kycLabel),
        _TimelineStep(done: emailDone, label: 'Activate E-mail ID'),
        _TimelineStep(done: enachDone, label: 'E-Nach'),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.accentMint : AppColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                size: 13,
                color: done ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InProcessRow extends StatelessWidget {
  const _InProcessRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 7, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 2,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentMint.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'In Process',
            style: AppTypography.body(size: 13, color: AppColors.accentMint),
          ),
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.done, required this.label});
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? AppColors.success : AppColors.muted,
          size: 22,
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTypography.body(size: 12, color: AppColors.muted)),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.label,
    required this.onTap,
  });
  final bool done;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: done ? null : onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? AppColors.success : AppColors.accentMint,
      ),
      title: Text(label, style: AppTypography.body(size: 15)),
      trailing: done
          ? null
          : const Icon(Icons.chevron_right, color: Colors.white54),
    );
  }
}

class CreditScoreTabScreen extends StatelessWidget {
  const CreditScoreTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Center(
        child: Text('Credit Score', style: AppTypography.headline(size: 22)),
      ),
    );
  }
}

class LearnTabScreen extends StatelessWidget {
  const LearnTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Center(
        child: Text('Learn', style: AppTypography.headline(size: 22)),
      ),
    );
  }
}

class RewardTabScreen extends StatelessWidget {
  const RewardTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Rewards coming soon\n(Flyy SDK stubbed until bridge is approved)',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
