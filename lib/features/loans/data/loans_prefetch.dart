import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/screen_status_resolver.dart';

/// Warm cache for My Loans (RN Profile → `createLoanContractPdf` pattern).
class LoansPrefetchState {
  const LoansPrefetchState({
    this.contracts = const [],
    this.flags,
    this.contractId,
    this.loanAccount,
    this.ready = false,
  });

  final List<Map<String, dynamic>> contracts;
  final ScreenCompletionFlags? flags;
  final String? contractId;
  final Map<String, dynamic>? loanAccount;
  final bool ready;

  LoansPrefetchState copyWith({
    List<Map<String, dynamic>>? contracts,
    ScreenCompletionFlags? flags,
    String? contractId,
    Map<String, dynamic>? loanAccount,
    bool? ready,
  }) {
    return LoansPrefetchState(
      contracts: contracts ?? this.contracts,
      flags: flags ?? this.flags,
      contractId: contractId ?? this.contractId,
      loanAccount: loanAccount ?? this.loanAccount,
      ready: ready ?? this.ready,
    );
  }
}

final loansPrefetchProvider =
    StateProvider<LoansPrefetchState>((ref) => const LoansPrefetchState());
