import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../payments/data/emi_payment_repository.dart';
import '../../../loans/data/esign_repository.dart';
import '../../../loans/data/references_repository.dart';
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
  EsignStatus? _esignStatus;
  LoanReferenceStatus? _referenceStatus;
  String? _error;
  bool _loading = true;
  final _resolver = const HomeCardResolver();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

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
      EsignStatus? esign;
      LoanReferenceStatus? references;
      final home = bundle.home;
      final shouldLoadEsign = home.peerStage.toLowerCase() == 'funded';
      if (shouldLoadEsign) {
        try {
          references = await ref
              .read(referencesRepositoryProvider)
              .fetchStatus();
        } catch (_) {
          references = null;
        }
        try {
          esign = await ref
              .read(esignRepositoryProvider)
              .fetchStatus(refresh: false);
        } catch (_) {
          esign = null;
        }
      }
      if (mounted) {
        setState(() {
          _bundle = bundle;
          _esignStatus = esign;
          _referenceStatus = references;
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

  void _openReferences() {
    if (!mounted) return;
    context.push(AppRoutes.references);
  }

  /// RN home Pre-Pay / Pay EMI modal → Cashfree EMI UPI checkout.
  Future<void> _showEmiPaymentSheet(HomeSnapshot home) async {
    final amount = home.installmentAmount;
    final contractId = home.contractId;
    if (amount == null ||
        amount <= 0 ||
        contractId == null ||
        contractId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EMI amount unavailable for this loan')),
      );
      return;
    }

    final due = home.installmentStartDate;
    final dueIn = due == null
        ? null
        : DateTime(due.year, due.month, due.day)
              .difference(
                DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                ),
              )
              .inDays;

    await showModalBottomSheet<void>(
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
                Row(
                  children: [
                    Text(
                      'EMI Payment',
                      style: AppTypography.headline(
                        size: 18,
                        color: AppColors.accentMint,
                      ),
                    ),
                    const Spacer(),
                    if (dueIn != null)
                      Text(
                        'DUE IN $dueIn Days',
                        style: AppTypography.body(size: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _startEmiCheckout(amount: amount, contractId: contractId);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pay EMI amount (${_currency.format(amount)})',
                              style: AppTypography.body(size: 14),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.accentMint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startEmiCheckout({
    required num amount,
    required String contractId,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await ref
          .read(emiPaymentRepositoryProvider)
          .createEmiCheckout(amount: amount, contractId: contractId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (result.mockPaid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('EMI payment recorded')));
        await _load();
        return;
      }

      final uri = Uri.parse(result.upiUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open UPI app')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete payment in your UPI app, then return here'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start EMI payment')),
      );
    }
  }

  void _openEsign() {
    if (!mounted) return;
    context.push(AppRoutes.esign);
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
                Text(
                  'Complete your process',
                  style: AppTypography.headline(size: 20),
                ),
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

  Future<void> _showLoanAmountRequestSheet() async {
    final controller = TextEditingController();
    var submitting = false;
    String? validationError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A0A5C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final amount = int.tryParse(controller.text.trim());
              if (amount == null || amount < 1000) {
                setSheetState(() {
                  validationError = 'Enter an amount of at least ₹1,000';
                });
                return;
              }

              setSheetState(() {
                submitting = true;
                validationError = null;
              });
              try {
                await ref
                    .read(homeRepositoryProvider)
                    .submitLoanAmountRequest(amount);
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Request submitted. Our team will contact you after review.',
                    ),
                  ),
                );
                await _load();
              } on DioException catch (error) {
                if (!sheetContext.mounted) return;
                final body = error.response?.data;
                final message = body is Map ? body['msg']?.toString() : null;
                setSheetState(() {
                  submitting = false;
                  validationError =
                      message ?? 'Could not submit your request. Try again.';
                });
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  submitting = false;
                  validationError = 'Could not submit your request. Try again.';
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'How much would you like to borrow?',
                      style: AppTypography.headline(size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your preferred amount. Our team will review your '
                      'profile and contact you with the amount available.',
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !submitting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Requested loan amount',
                        prefixText: '₹ ',
                        errorText: validationError,
                      ),
                      onSubmitted: submitting ? null : (_) => submit(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: submitting ? null : submit,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit for review'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
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
            loanRequestStatus: credit?.loanRequestStatus,
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
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push(AppRoutes.profile),
                    icon: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentMint,
                    ),
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

    switch (kind) {
      case HomeCardKind.activeLoan:
      case HomeCardKind.loanCompleted:
        return _LoanCard(
          home: home!,
          currency: _currency,
          completed: kind == HomeCardKind.loanCompleted,
          onViewLoan: () =>
              context.push(AppRoutes.myLoans, extra: home.contractId),
          onPrePay: () => _showEmiPaymentSheet(home),
          // A repaid loan starts a fresh underwriting cycle. The backend has
          // invalidated bureau, income/bank and mandate steps; begin with a new
          // credit pull instead of generating an offer from stale data.
          onApplyNewLoan: () => context.go(AppRoutes.equifax),
        );
      case HomeCardKind.funding:
        final isSalaried =
            (_bundle?.userType ?? '').toLowerCase() == 'salaried';
        final loanFunded = (home?.peerStage ?? '').toLowerCase() == 'funded';
        final hasSigningLink =
            loanFunded &&
            (_esignStatus?.signingLink?.trim().isNotEmpty ?? false);
        final esignDone = loanFunded && _esignStatus?.isSigned == true;
        // References are required before e-sign.
        final referencesDone =
            loanFunded && (_referenceStatus?.complete == true);
        final referencesPending = loanFunded && !referencesDone;
        final canSign = hasSigningLink && referencesDone && !esignDone;
        final fundingBody = referencesPending
            ? 'Add 2 personal references before signing your loan agreement.'
            : canSign
            ? 'Your loan agreement is ready. Sign it to proceed with disbursement.'
            : loanFunded && !esignDone
            ? 'Your loan is funded. We will notify you when the agreement is ready to sign.'
            : 'Your loan is in process of funding';
        return _HeroCard(
          title: 'Disbursal Process',
          body: fundingBody,
          accentAsset: 'assets/images/profile/homecoins.png',
          actionLabel: referencesPending
              ? 'Add references'
              : canSign
              ? 'Sign loan agreement'
              : null,
          onAction: referencesPending
              ? _openReferences
              : canSign
              ? _openEsign
              : null,
          timeline: _FundingTimeline(
            kycLabel: isSalaried ? 'Video KYC' : 'Digital KYC',
            loanFunded: loanFunded,
            esignDone: esignDone,
            esignPending:
                canSign || (hasSigningLink && referencesDone && !esignDone),
            referencesDone: referencesDone,
            referencesPending: referencesPending,
          ),
        );
      case HomeCardKind.cancelled:
        return _HeroCard(
          title: 'Loan cancelled',
          body:
              'This application was cancelled and isn’t eligible for re-apply yet.',
          actionLabel: 'Go to profile',
          onAction: () => context.push(AppRoutes.profile),
        );
      case HomeCardKind.cancelReapply:
        return _HeroCard(
          title: 'Ready to re-apply',
          body:
              'Your previous application was cancelled. You can start a new loan request.',
          actionLabel: 'Apply again',
          onAction: () => context.go(AppRoutes.waiting),
        );
      case HomeCardKind.completeProcess:
        final kycDone = (flags?.ocr == true) || (flags?.vkyc == true);
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
            esignDone: false,
            esignPending: false,
          ),
          actionLabel: 'Take action',
          onAction: () => _showCompleteProcessSheet(home!),
        );
      case HomeCardKind.creditRequest:
        return _HeroCard(
          title: 'How much do you need?',
          body:
              'Tell us your preferred loan amount. Our team will review your '
              'scores and other eligibility criteria, then contact you.',
          accentAsset: 'assets/images/profile/homecoins.png',
          actionLabel: 'Enter loan amount',
          onAction: _showLoanAmountRequestSheet,
        );
      case HomeCardKind.creditOffer:
        final amount = credit?.approvedAmount ?? credit?.maxLoanAmount;
        return _HeroCard(
          title: 'Your loan offer is ready',
          body: amount != null
              ? '${_currency.format(amount)} has been approved after review'
              : 'Your approved loan offer is ready',
          accentAsset: 'assets/images/profile/homecoins.png',
          actionLabel: 'View offer',
          onAction: () => context.push(AppRoutes.offer),
        );
      case HomeCardKind.creditPending:
        final requested = credit?.requestedAmount;
        return _HeroCard(
          title: 'Your request is under review',
          body: requested == null
              ? 'Our team is reviewing your application and will contact you '
                    'to discuss the amount available.'
              : 'We received your request for '
                    '${_currency.format(requested)}. Our team will review it and '
                    'contact you.',
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
    this.accentAsset,
    this.timeline,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? accentAsset;
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
            Image.asset(
              accentAsset!,
              height: 56,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
            const SizedBox(height: 12),
          ],
          Text(title, style: AppTypography.headline(size: 22)),
          const SizedBox(height: 10),
          Text(
            body,
            style: AppTypography.body(size: 14, color: AppColors.muted),
          ),
          if (timeline != null) ...[const SizedBox(height: 16), timeline!],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ZapSubmitButton(title: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// RN home "Your Loan" card: installment progress, loan facts and a due strip.
class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.home,
    required this.currency,
    required this.completed,
    required this.onViewLoan,
    required this.onPrePay,
    required this.onApplyNewLoan,
  });

  final HomeSnapshot home;
  final NumberFormat currency;
  final bool completed;
  final VoidCallback onViewLoan;
  final VoidCallback onPrePay;
  final VoidCallback onApplyNewLoan;

  @override
  Widget build(BuildContext context) {
    final total = home.totalInstallments ?? 0;
    final paid = home.paidInstallments;
    final amount = home.loanAmount ?? home.approvedAmount;
    final canApply = home.canApplyForNewLoan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  completed ? 'Loan repaid' : 'Your Loan',
                  style: AppTypography.headline(size: 20),
                ),
              ),
              if (amount != null)
                Text(
                  currency.format(amount),
                  style: AppTypography.headline(
                    size: 22,
                    color: AppColors.accentMint,
                  ),
                ),
            ],
          ),
          if (home.contractId != null) ...[
            const SizedBox(height: 4),
            Text(
              home.contractId!,
              style: AppTypography.body(size: 11, color: AppColors.muted),
            ),
          ],
          if (total > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Installments',
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.accentMint,
                    ),
                  ),
                ),
                Text(
                  '$paid of $total paid',
                  style: AppTypography.body(size: 11, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InstallmentProgress(total: total, paid: paid),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                if (home.installmentStartDate != null)
                  _LoanFactRow(
                    label: 'Start Date',
                    value: _formatDay(home.installmentStartDate!),
                  ),
                if (total > 0)
                  _LoanFactRow(label: 'Loan tenure', value: '$total M'),
                if (home.installmentAmount != null)
                  _LoanFactRow(
                    label: 'EMI Amount',
                    value: currency.format(home.installmentAmount),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DueStatusStrip(
            completed: completed,
            overdueDays: home.overdueDays,
            nextInstallmentLabel: _nextInstallmentLabel(paid, total),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: completed
                ? (canApply ? onApplyNewLoan : onViewLoan)
                : onPrePay,
            child: Text(
              completed
                  ? (canApply ? 'Apply for New Loan' : 'View loan')
                  : 'Pre-Pay',
            ),
          ),
          if (!completed || canApply)
            TextButton(
              onPressed: onViewLoan,
              child: Text(
                'View loan details',
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.accentMint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _nextInstallmentLabel(int paid, int total) {
    final raw = home.nextInstallmentDate;
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    final next = total > 0 ? (paid + 1).clamp(1, total) : paid + 1;
    return '${_ordinal(next)} EMI Due Date : ${_formatFullDay(date)}';
  }
}

class _LoanFactRow extends StatelessWidget {
  const _LoanFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body(size: 12)),
          Text(
            value,
            style: AppTypography.body(size: 12, color: AppColors.accentMint),
          ),
        ],
      ),
    );
  }
}

/// Segmented EMI bar mirroring RN `setuSteps` (one segment per installment).
class _InstallmentProgress extends StatelessWidget {
  const _InstallmentProgress({required this.total, required this.paid});

  final int total;
  final int paid;

  @override
  Widget build(BuildContext context) {
    // Per-segment ordinals get unreadable on long tenures; the header already
    // carries the "x of y paid" count in that case.
    final showLabels = total <= 8;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: i <= paid
                        ? AppColors.accentMint
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(i == 1 ? 6 : 2),
                      right: Radius.circular(i == total ? 6 : 2),
                    ),
                  ),
                ),
              ),
              if (i != total) const SizedBox(width: 3),
            ],
          ],
        ),
        if (showLabels) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                Expanded(
                  child: Text(
                    _ordinal(i),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: AppTypography.body(
                      size: 9,
                      color: i <= paid
                          ? AppColors.accentMint
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                if (i != total) const SizedBox(width: 3),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// RN due strip: mint when repaid, red when an EMI is overdue, else neutral.
class _DueStatusStrip extends StatelessWidget {
  const _DueStatusStrip({
    required this.completed,
    required this.overdueDays,
    required this.nextInstallmentLabel,
  });

  final bool completed;
  final int? overdueDays;
  final String? nextInstallmentLabel;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final IconData icon;
    late final String message;

    if (completed) {
      background = AppColors.accentMint.withValues(alpha: 0.16);
      foreground = AppColors.accentMint;
      icon = Icons.check_circle_outline;
      message = 'Congratulation, you have completed loan re-payment';
    } else if (overdueDays != null) {
      background = const Color(0xFFFF0047);
      foreground = AppColors.white;
      icon = Icons.error_outline;
      message = 'You have missed your EMI due date by $overdueDays days';
    } else {
      background = Colors.white.withValues(alpha: 0.07);
      foreground = AppColors.white;
      icon = Icons.event_outlined;
      message = nextInstallmentLabel ?? 'Your EMI schedule is being prepared';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body(size: 12, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDay(DateTime date) =>
    '${date.day}${_ordinalSuffix(date.day)} ${DateFormat('MMM').format(date)}';

String _formatFullDay(DateTime date) => '${_formatDay(date)} ${date.year}';

String _ordinal(int n) => '$n${_ordinalSuffix(n)}';

String _ordinalSuffix(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return 'th';
  switch (n % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

/// RN home funding card after KYC + email + eNACH (Disbursal_Bank_Status blank).
class _FundingTimeline extends StatelessWidget {
  const _FundingTimeline({
    required this.kycLabel,
    required this.loanFunded,
    this.esignDone = false,
    this.esignPending = false,
    this.referencesDone = false,
    this.referencesPending = false,
  });

  final String kycLabel;
  final bool loanFunded;
  final bool esignDone;
  final bool esignPending;
  final bool referencesDone;
  final bool referencesPending;

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
        if (loanFunded || referencesPending || referencesDone)
          _TimelineStep(
            done: referencesDone,
            label: referencesPending && !referencesDone
                ? 'Add 2 references (pending)'
                : 'References submitted',
          ),
        if (loanFunded || esignPending || esignDone)
          _TimelineStep(
            done: esignDone,
            label: esignPending && !esignDone
                ? 'Sign loan agreement (pending)'
                : 'Loan agreement signed',
          ),
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
    this.esignDone = false,
    this.esignPending = false,
  });

  final bool kycDone;
  final String kycLabel;
  final bool emailDone;
  final bool enachDone;
  final bool esignDone;
  final bool esignPending;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineStep(done: kycDone, label: kycLabel),
        _TimelineStep(done: emailDone, label: 'Activate E-mail ID'),
        _TimelineStep(done: enachDone, label: 'E-Nach'),
        if (esignPending || esignDone)
          _TimelineStep(
            done: esignDone,
            label: esignPending && !esignDone
                ? 'Sign loan agreement (pending)'
                : 'Loan agreement signed',
          ),
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
