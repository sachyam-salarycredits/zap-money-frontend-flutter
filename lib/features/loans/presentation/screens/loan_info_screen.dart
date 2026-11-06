import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../profile/data/profile_repository.dart';

/// Details of one contract, opened from the home loan card.
/// Profile → My Loans stays on the loan history screen.
class LoanInfoScreen extends ConsumerStatefulWidget {
  const LoanInfoScreen({super.key, this.contractId});

  final String? contractId;

  @override
  ConsumerState<LoanInfoScreen> createState() => _LoanInfoScreenState();
}

class _LoanInfoScreenState extends ConsumerState<LoanInfoScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

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
    final id = widget.contractId?.trim();
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This loan could not be identified.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(profileRepositoryProvider).fetchLoanStatus(id);
      if (!mounted) return;
      final status = detail?['loanStatus']?.toString();
      if (detail == null || status == 'NOT_FOUND') {
        setState(() {
          _loading = false;
          _error = 'Loan details are not available for $id.';
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this loan.';
      });
    }
  }

  String _money(dynamic raw) {
    if (raw == null) return '—';
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null) return raw.toString();
    if ((n * 100).round() % 100 != 0) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      ).format(n);
    }
    return _currency.format(n);
  }

  String _date(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return '—';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return DateFormat('d MMM yyyy').format(parsed);
  }

  String _tenure(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return '—';
    if (text.toLowerCase().contains('month')) return text;
    return '$text months';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final contractId =
        detail?['contractId']?.toString() ?? widget.contractId ?? '';
    final stage = detail?['loanStage']?.toString() ?? '';

    return FunnelScaffold(
      title: 'Loan details',
      showHelp: false,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentMint),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(size: 14),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _field('Loan ID', contractId.isEmpty ? '—' : contractId),
                    if (stage.isNotEmpty) _field('Stage', stage),
                    _field('Loan amount', _money(detail?['loanAmount'])),
                    _field('Tenure', _tenure(detail?['loanTenure'])),
                    _field(
                      'Remaining EMIs',
                      detail?['remainingEmi']?.toString() ?? '—',
                    ),
                    _field('Next EMI date', _date(detail?['nextDate'])),
                    _field('Amount due', _money(detail?['loanDue'])),
                    _field(
                      'Amount credited',
                      _money(
                        detail?['netDisbursement'] ?? detail?['dibursalAmount'],
                      ),
                    ),
                    _field('Disbursal date', _date(detail?['disbursalDate'])),
                  ],
                ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(size: 14, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.body(size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
