import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../../payments/data/emi_payment_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/loan_contract_pdf.dart';
import '../../data/loans_prefetch.dart';

/// RN My Loans gate → NoLoans or LoanDetails.
class MyLoansScreen extends ConsumerStatefulWidget {
  const MyLoansScreen({super.key, this.contractId});

  final String? contractId;

  @override
  ConsumerState<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends ConsumerState<MyLoansScreen> {
  bool _loading = true;
  String? _error;
  String? _contractId;
  Map<String, dynamic>? _loanDetail;
  Map<String, dynamic>? _loanAccount;
  List<Map<String, dynamic>> _contracts = const [];
  ScreenCompletionFlags _flags = const ScreenCompletionFlags();
  bool _stageModal = false;
  bool _cancelModal = false;
  bool _paymentModal = false;
  bool _downloadingPdf = false;
  int? _downloadingPdfIndex;

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final cached = ref.read(loansPrefetchProvider);
    var contractId = widget.contractId?.trim();
    if (contractId == null || contractId.isEmpty) {
      contractId = cached.contractId;
    }

    // Paint immediately from Profile prefetch (RN Redux pattern).
    if (cached.ready) {
      setState(() {
        _flags = cached.flags ?? _flags;
        _contracts = cached.contracts;
        _contractId = contractId;
        _loanAccount = cached.loanAccount;
        _error = null;
        // Still fetch LoanStatus unless we already have no loan at all.
        _loading = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repo = ref.read(profileRepositoryProvider);
      final homeRepo = ref.read(homeRepositoryProvider);

      // Fast path: Profile already warmed contracts + contractId → LoanStatus only (RN).
      if (contractId != null && contractId.isNotEmpty) {
        if (cached.ready) {
          final status = await repo.fetchLoanStatus(contractId);
          if (!mounted) return;
          setState(() {
            _flags = cached.flags ?? _flags;
            _contracts = cached.contracts;
            _contractId = contractId;
            _loanAccount = cached.loanAccount ?? _loanAccount;
            _loanDetail = status;
            _loading = false;
          });
          return;
        }

        final results = await Future.wait([
          repo.fetchFlags(),
          repo.fetchLoanContractPdfs().catchError(
            (_) => <Map<String, dynamic>>[],
          ),
          repo.fetchLoanStatus(contractId),
        ]);
        if (!mounted) return;
        final flags = results[0] as ScreenCompletionFlags;
        final contracts = results[1] as List<Map<String, dynamic>>;
        final status = results[2] as Map<String, dynamic>?;
        setState(() {
          _flags = flags;
          _contracts = contracts;
          _contractId = contractId;
          _loanAccount = _loanAccount;
          _loanDetail = status;
          _loading = false;
        });
        ref.read(loansPrefetchProvider.notifier).state = LoansPrefetchState(
          contracts: contracts,
          flags: flags,
          contractId: contractId,
          loanAccount: _loanAccount,
          ready: true,
        );
        return;
      }

      // Cold path: resolve id via light home + contracts in parallel (no CD bundle).
      final results = await Future.wait([
        repo.fetchFlags(),
        repo.fetchLoanContractPdfs().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
        homeRepo.fetchContractHint(),
      ]);
      if (!mounted) return;

      final flags = results[0] as ScreenCompletionFlags;
      final contracts = results[1] as List<Map<String, dynamic>>;
      final hint = results[2]
          as ({String? contractId, Map<String, dynamic>? loanAccount});

      contractId = hint.contractId;
      Map<String, dynamic>? loanAccount = hint.loanAccount;
      if (contractId == null || contractId.isEmpty) {
        for (final c in contracts) {
          final lai = c['lai']?.toString();
          if (lai != null && lai.isNotEmpty) {
            contractId = lai;
            break;
          }
        }
      }

      Map<String, dynamic>? status;
      if (contractId != null && contractId.isNotEmpty) {
        status = await repo.fetchLoanStatus(contractId);
      }

      if (!mounted) return;
      setState(() {
        _flags = flags;
        _contracts = contracts;
        _contractId = contractId;
        _loanAccount = loanAccount;
        _loanDetail = status;
        _loading = false;
      });
      ref.read(loansPrefetchProvider.notifier).state = LoansPrefetchState(
        contracts: contracts,
        flags: flags,
        contractId: contractId,
        loanAccount: loanAccount,
        ready: true,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load loan details';
        });
      }
    }
  }

  bool get _hasLoan {
    final id = _contractId;
    if (id != null && id.isNotEmpty) return true;
    return _contracts.isNotEmpty;
  }

  /// Mirrors RN `showLoanStage`.
  String _displayStage(String? stage) {
    final detail = _loanDetail;
    final status = detail?['loanStatus']?.toString() ??
        detail?['loanStage']?.toString() ??
        stage;
    final s = stage ?? status ?? '';
    final enach = _flags.enach;
    final vkyc = _flags.vkyc;
    if ((s == 'ready to fund' || s == 'Ready To Fund') &&
        detail?['loanStatus'] == 'Partial Application') {
      return s;
    }
    if (detail?['loanStatus'] == 'Partial Application' || !enach || !vkyc) {
      return 'In Progress';
    }
    if (s == 'Canceled' || s == 'Cancelled') {
      if ((!vkyc || !enach)) {
        return 'Cancelled';
      }
      return 'Un-funded';
    }
    if (s == 'Funded') return 'Funded';
    if (s == 'In Funding' || s == 'Funding') return 'In Progress';
    if (s == 'Ongoing' || s == 'Disbursed') return 'Ongoing';
    return s.isEmpty ? 'In Progress' : s;
  }

  Color _badgeBg(String rawStage, String display) {
    if (rawStage == 'Funded' || display == 'Funded') {
      return AppColors.accentMint;
    }
    if (rawStage == 'Canceled' ||
        rawStage == 'Cancelled' ||
        display == 'Cancelled' ||
        display == 'Un-funded') {
      return Colors.red;
    }
    return const Color(0xFF3E1982);
  }

  Color _badgeFg(String rawStage, String display) {
    if (rawStage == 'Funded' || display == 'Funded') {
      return AppColors.deepPurple;
    }
    if (rawStage == 'Canceled' ||
        rawStage == 'Cancelled' ||
        display == 'Cancelled' ||
        display == 'Un-funded') {
      return Colors.white;
    }
    return AppColors.accentMint;
  }

  String _formatAmount(dynamic raw) {
    if (raw == null) return '—';
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null) return raw.toString();
    return _currency.format(n);
  }

  String _tenureLabel(dynamic raw) {
    if (raw == null) return '-';
    final s = raw.toString().trim();
    if (s.isEmpty) return '-';
    if (s.toLowerCase().contains('month')) return s;
    return '$s Months';
  }

  bool get _showActiveCard {
    final detail = _loanDetail;
    if (detail == null) return _hasLoan;
    final loanStatus = detail['loanStatus']?.toString() ?? '';
    if (loanStatus == 'Closed - Obligations met' ||
        loanStatus == 'NOT_FOUND' ||
        loanStatus == 'Closed') {
      return false;
    }
    final stage = detail['loanStage']?.toString();
    final amount = detail['loanAmount'];
    return _flags.dc ||
        _flags.pl ||
        (stage != null && stage.isNotEmpty) ||
        amount != null ||
        _hasLoan;
  }

  bool get _showCancelledReasons {
    final stage = _loanDetail?['loanStage']?.toString() ?? '';
    if (stage != 'Canceled' && stage != 'Cancelled') return false;
    return !_flags.vkyc || !_flags.enach;
  }

  void _onCheckUpdate() {
    final stage = _loanDetail?['loanStage']?.toString() ?? '';
    if (stage == 'Partial Application') {
      context.go(AppRoutes.home);
      return;
    }
    const openModal = {
      'In Funding',
      'Funding',
      'Funded',
      'Ready To Fund',
      'Ongoing',
      'Disbursed',
    };
    if (openModal.contains(stage)) {
      setState(() => _stageModal = true);
    } else {
      setState(() => _cancelModal = true);
    }
  }

  Future<void> _downloadContract(Map<String, dynamic> offer, int index) async {
    if (_downloadingPdf) return;
    setState(() {
      _downloadingPdf = true;
      _downloadingPdfIndex = index;
    });
    try {
      // Prefer nested `data` if hub wrapped it like RN `{ id, value, data }`.
      final payload = offer['data'] is Map
          ? Map<String, dynamic>.from(offer['data'] as Map)
          : offer;
      await LoanContractPdfService.downloadOrShare(
        offer: payload,
        index: index,
        borrowerName: _loanDetail?['customerName']?.toString() ??
            _loanAccount?['Name']?.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan contract downloaded successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download contract. $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPdf = false;
          _downloadingPdfIndex = null;
        });
      }
    }
  }

  int? get _emiAmount {
    final detail = _loanDetail;
    if (detail == null) return null;
    // Prefer backend EMI (`loanDue`); do not divide principal by tenure.
    for (final key in ['loanDue', 'emiAmount', 'emi']) {
      final raw = detail[key];
      final n = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '');
      if (n != null && n > 0) return n.round();
    }
    return null;
  }

  int? get _daysUntilDue {
    final next = _loanDetail?['nextDate']?.toString();
    if (next == null || next.isEmpty) return null;
    final due = DateTime.tryParse(next);
    if (due == null) return null;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(due.year, due.month, due.day);
    return end.difference(start).inDays;
  }

  /// Same Cashfree EMI checkout as Home Pre-Pay.
  Future<void> _startEmiCheckout() async {
    final amount = _emiAmount;
    final contractId = _contractId?.trim();
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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result =
          await ref.read(emiPaymentRepositoryProvider).createEmiCheckout(
                amount: amount,
                contractId: contractId,
              );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (result.mockPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('EMI payment recorded')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open UPI app')),
        );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return FunnelScaffold(
        title: 'My Loans',
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accentMint),
        ),
      );
    }

    if (!_hasLoan && _loanDetail == null) {
      return _NoLoansBody(onApply: () => context.go(AppRoutes.home));
    }

    final detail = _loanDetail ?? const <String, dynamic>{};
    final stage = detail['loanStage']?.toString() ??
        detail['loanStatus']?.toString() ??
        '';
    final display = _displayStage(stage);
    final transactions = detail['transactionHistory'];
    final txList = transactions is List
        ? transactions
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF633AB1),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Loan Details',
                          style: AppTypography.headline(size: 25),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.push(
                            AppRoutes.loanTransactions,
                            extra: {
                              'loan_amount': detail['amountFunded'],
                              'date': detail['disbursalDate'],
                              'disbursal_name': detail['disbursementName'],
                              'transactionList': txList,
                            },
                          );
                        },
                        child: Container(
                          height: 41,
                          width: 152,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E1982),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'View Transactions',
                            style: AppTypography.body(size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(35, 2, 97, 0.8),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                    ),
                    child: RefreshIndicator(
                      color: AppColors.accentMint,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                              child: Text(
                                _error!,
                                style: AppTypography.body(
                                  size: 13,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          if (_showActiveCard) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stage == 'Canceled' &&
                                              _showCancelledReasons
                                          ? 'Loan Application'
                                          : 'Active Loan',
                                      style: AppTypography.body(
                                        size: 18,
                                        weight: FontWeight.w600,
                                        color: AppColors.accentMint,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 104,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _badgeBg(stage, display),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      display,
                                      style: AppTypography.body(
                                        size: 10,
                                        color: _badgeFg(stage, display),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (detail['loanAmount'] != null ||
                                _loanAccount?['loan__Loan_Amount__c'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 18, 20, 0),
                                child: Text(
                                  'Loan Amount ${_formatAmount(detail['loanAmount'] ?? _loanAccount?['loan__Loan_Amount__c'])}',
                                  style: AppTypography.body(
                                    size: 18,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (!_showCancelledReasons)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 10),
                                child: Row(
                                  children: [
                                    _WhitePillButton(
                                      label: stage == 'Partial Application'
                                          ? 'Complete Application'
                                          : 'Check Update',
                                      onPressed: _onCheckUpdate,
                                    ),
                                    if (stage == 'Ongoing' ||
                                        stage == 'Disbursed' ||
                                        display == 'Ongoing') ...[
                                      const SizedBox(width: 12),
                                      _WhitePillButton(
                                        label: 'Pay EMI',
                                        onPressed: () => setState(
                                          () => _paymentModal = true,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                              child: Text(
                                "You don't have any active loans",
                                style: AppTypography.body(size: 14),
                              ),
                            ),
                          ],
                          if (_showCancelledReasons) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                              child: Text(
                                'Reasons',
                                style: AppTypography.body(
                                  size: 18,
                                  weight: FontWeight.w600,
                                  color: AppColors.accentMint,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
                              child: Text(
                                'Your loan application was cancelled as you\nfailed to complete the following steps',
                                style: AppTypography.body(
                                  size: 12,
                                  color: const Color(0xFFAC9FC6),
                                ),
                              ),
                            ),
                            _ReasonRow(
                              done: _flags.vkyc,
                              label: 'Digital KYC',
                            ),
                            _ReasonRow(
                              done: false,
                              label: 'Activate E-mail ID',
                            ),
                            _ReasonRow(
                              done: _flags.enach,
                              label: 'E-Nach',
                            ),
                            ZapSubmitButton(
                              title: 'Re-apply',
                              onPressed: () => context.go(AppRoutes.home),
                            ),
                          ] else ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Divider(
                                color: Color(0xFF633AB1),
                                height: 32,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Text(
                                'History',
                                style: AppTypography.body(
                                  size: 18,
                                  weight: FontWeight.w600,
                                  color: AppColors.accentMint,
                                ),
                              ),
                            ),
                            if (_contracts.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  "You don't have any loan history",
                                  style: AppTypography.body(size: 14),
                                ),
                              )
                            else
                              ..._contracts.asMap().entries.map((entry) {
                                final index = entry.key;
                                final c = entry.value;
                                final disbursement = c['disbursement'] ??
                                    (c['data'] is Map
                                        ? (c['data'] as Map)['disbursement']
                                        : null);
                                final map = disbursement is Map
                                    ? Map<String, dynamic>.from(disbursement)
                                    : <String, dynamic>{};
                                final amt = map['loanAmt'] ??
                                    c['loanAmt'] ??
                                    c['offeredLoanAmt'] ??
                                    (c['data'] is Map
                                        ? (c['data'] as Map)['offeredLoanAmt']
                                        : null);
                                final pd = c['pd'] is Map
                                    ? Map<String, dynamic>.from(c['pd'] as Map)
                                    : <String, dynamic>{};
                                final dt = map['dt']?.toString().isNotEmpty == true
                                    ? map['dt']
                                    : (c['dt'] ?? pd['dateAndTime'] ?? '');
                                final rawName = c['DocumentName']?.toString();
                                final titleFallback =
                                    (rawName != null &&
                                            rawName.isNotEmpty &&
                                            !rawName
                                                .toLowerCase()
                                                .contains('salary_slip'))
                                        ? rawName
                                        : 'Loan Contract';
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _downloadingPdf
                                        ? null
                                        : () => _downloadContract(c, index),
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        10,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFF633AB1),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  amt != null
                                                      ? 'Loan of ${_formatAmount(amt)}'
                                                      : titleFallback,
                                                  style: AppTypography.body(
                                                    size: 14,
                                                  ),
                                                ),
                                                if (dt
                                                    .toString()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    dt.toString(),
                                                    style: AppTypography.body(
                                                      size: 12,
                                                      color: AppColors.muted,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (_downloadingPdfIndex == index)
                                            const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.accentMint,
                                              ),
                                            )
                                          else
                                            Image.asset(
                                              'assets/images/loans/download_icon.png',
                                              height: 22,
                                              width: 22,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.download,
                                                color: AppColors.accentMint,
                                                size: 22,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_stageModal)
          _StageModal(
            detail: detail,
            displayStage: display,
            contractId: _contractId,
            formatAmount: _formatAmount,
            tenureLabel: _tenureLabel,
            onClose: () => setState(() => _stageModal = false),
            onComplete: () {
              setState(() => _stageModal = false);
              if (!_flags.vkyc) {
                context.push(AppRoutes.dkyc);
              } else if (!_flags.enach) {
                context.push(AppRoutes.enach);
              } else if (display == 'Funded') {
                context.push(AppRoutes.esign);
              }
            },
          ),
        if (_paymentModal)
          _PayEmiModal(
            emiAmount: _emiAmount,
            daysUntilDue: _daysUntilDue,
            onClose: () => setState(() => _paymentModal = false),
            onPay: () {
              setState(() => _paymentModal = false);
              _startEmiCheckout();
            },
          ),
        if (_cancelModal)
          _CancelModal(
            onClose: () => setState(() => _cancelModal = false),
            onReapply: () {
              setState(() => _cancelModal = false);
              context.go(AppRoutes.home);
            },
          ),
      ],
    );
  }
}

class _WhitePillButton extends StatelessWidget {
  const _WhitePillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: 151,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.deepPurple,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.add_circle_outline,
            size: 15,
            color: done ? AppColors.accentMint : Colors.white70,
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTypography.body(size: 13)),
        ],
      ),
    );
  }
}

class _NoLoansBody extends StatelessWidget {
  const _NoLoansBody({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/loans/noLoanBg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: AppColors.deepPurple),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/images/loans/noLoanImg.png',
                  height: 160,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/profile/noLoanImg.png',
                    height: 160,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 120),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "You haven't applied for a loan yet",
                  textAlign: TextAlign.center,
                  style: AppTypography.headline(size: 20),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ZapSubmitButton(
                    title: 'Apply Now',
                    onPressed: onApply,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// RN `LoanStageModal` — bottom sheet with bordered rows, progress, Note.
class _StageModal extends StatelessWidget {
  const _StageModal({
    required this.detail,
    required this.displayStage,
    required this.contractId,
    required this.formatAmount,
    required this.tenureLabel,
    required this.onClose,
    required this.onComplete,
  });

  final Map<String, dynamic> detail;
  final String displayStage;
  final String? contractId;
  final String Function(dynamic) formatAmount;
  final String Function(dynamic) tenureLabel;
  final VoidCallback onClose;
  final VoidCallback onComplete;

  String _value(dynamic v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  @override
  Widget build(BuildContext context) {
    final funded = detail['amountFunded'];
    final amount = detail['loanAmount'];
    double progress = 0;
    final pct = detail['percentFunded'];
    if (pct is num) {
      progress = (pct.toDouble() / 100).clamp(0.0, 1.0);
    } else if (funded is num && amount is num && amount > 0) {
      progress = (funded / amount).clamp(0.0, 1.0);
    }

    final loanId = contractId ??
        detail['contractId']?.toString() ??
        detail['loanId']?.toString();

    final inProgressRows = <MapEntry<String, String>>[
      MapEntry('Loan Type', _value(detail['loanType'])),
      MapEntry('Loan ID', _value(loanId)),
      MapEntry('Loan Amount', formatAmount(detail['loanAmount'])),
      MapEntry('Loan Tenure', tenureLabel(detail['loanTenure'])),
    ];

    String nextDate = '-';
    final rawNext = detail['nextDate']?.toString();
    if (rawNext != null && rawNext.isNotEmpty) {
      final parsed = DateTime.tryParse(rawNext);
      nextDate = parsed != null
          ? DateFormat('d MMMM, yyyy').format(parsed)
          : rawNext;
    }

    final ongoingRows = <MapEntry<String, String>>[
      MapEntry('Loan Amount', formatAmount(detail['loanAmount'])),
      MapEntry('Loan Tenure', tenureLabel(detail['loanTenure'])),
      MapEntry('Loan Due', formatAmount(detail['loanDue'])),
      MapEntry('Next EMI Due Date', nextDate),
    ];

    final note = displayStage == 'In Progress'
        ? 'If your loan amount does not get funded within\nthe limited days your application will expire\nautomatically'
        : 'Get the amount credited to your account by\ncompleting your E-Nach & email verification';

    return Material(
      color: const Color(0x66000000),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.8,
          widthFactor: 1,
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(35, 2, 97, 0.95),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 25, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      if (displayStage != 'Ongoing') ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 30, 25, 0),
                          child: Text(
                            displayStage,
                            style: AppTypography.body(
                              size: 18,
                              weight: FontWeight.w600,
                              color: AppColors.accentMint,
                            ),
                          ),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.fromLTRB(25, 20, 25, 0),
                        child: Divider(color: Color(0xFF633AB1), height: 1),
                      ),
                      if (displayStage == 'In Progress')
                        ...inProgressRows.map(_detailRow),
                      if (displayStage == 'Ongoing')
                        ...ongoingRows.map(_detailRow),
                      if (displayStage == 'Funded')
                        ...inProgressRows.map(_detailRow),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: const Color(0xFF633AB1),
                                color: const Color(0xFF4A6CFF),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Funded',
                                  style: AppTypography.body(size: 12),
                                ),
                                const Spacer(),
                                Text(
                                  formatAmount(funded ?? 0),
                                  style: AppTypography.body(size: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E1982),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Note',
                              style: AppTypography.body(
                                size: 14,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              note,
                              style: AppTypography.body(
                                size: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (displayStage == 'Funded')
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.35,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: onComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.deepPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                textStyle: AppTypography.body(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: AppColors.deepPurple,
                                ),
                              ),
                              child: const Text('Complete now'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(MapEntry<String, String> item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 25, right: 25),
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF633AB1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.key,
              style: AppTypography.body(size: 15, weight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              textAlign: TextAlign.right,
              style: AppTypography.body(size: 15, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayEmiModal extends StatelessWidget {
  const _PayEmiModal({
    required this.emiAmount,
    required this.daysUntilDue,
    required this.onClose,
    required this.onPay,
  });

  final int? emiAmount;
  final int? daysUntilDue;
  final VoidCallback onClose;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.7,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(48, 14, 113, 1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white, size: 25),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(
                  children: [
                    Text(
                      'EMI Payment',
                      style: AppTypography.body(
                        size: 18,
                        weight: FontWeight.w600,
                        color: AppColors.accentMint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      daysUntilDue == null
                          ? 'Due —'
                          : 'Due in $daysUntilDue Days',
                      style: AppTypography.body(size: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: onPay,
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.only(left: 10, right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E1982),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          emiAmount == null
                              ? 'Pay EMI amount'
                              : 'Pay EMI amount (₹$emiAmount)',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelModal extends StatelessWidget {
  const _CancelModal({required this.onClose, required this.onReapply});

  final VoidCallback onClose;
  final VoidCallback onReapply;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0A5C),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Image.asset(
                'assets/images/loans/unfunded.png',
                height: 100,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.money_off,
                  size: 72,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sorry, your loan amount\nwas not funded',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  size: 18,
                  weight: FontWeight.w600,
                  color: AppColors.accentMint,
                ),
              ),
              const SizedBox(height: 20),
              ZapSubmitButton(title: 'Re-apply', onPressed: onReapply),
            ],
          ),
        ),
      ),
    );
  }
}

class LoanTransactionsScreen extends StatelessWidget {
  const LoanTransactionsScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    final list = (args?['transactionList'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final loanAmount = args?['loan_amount'];
    final date = args?['date'];
    final disbursalName = args?['disbursal_name'];

    return FunnelScaffold(
      title: 'Transactions',
      child: list.isEmpty && loanAmount == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OOPS!!', style: AppTypography.headline(size: 22)),
                  const SizedBox(height: 8),
                  Text(
                    "You don't have any transaction history",
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...list.map((tx) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0A5C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMI Paid',
                          style: AppTypography.headline(size: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tx['name']?.toString() ??
                              tx['disbursement_name']?.toString() ??
                              '—',
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tx['date'] ?? tx['emiDate'] ?? ''}  ·  ₹${tx['emiAmount'] ?? tx['amount'] ?? ''}',
                          style: AppTypography.body(size: 13),
                        ),
                      ],
                    ),
                  );
                }),
                if (loanAmount != null) ...[
                  const SizedBox(height: 12),
                  Text('Disbursal', style: AppTypography.headline(size: 16)),
                  const SizedBox(height: 8),
                  Text(
                    '₹$loanAmount · ${date ?? ''} · ${disbursalName ?? ''}',
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
