/// Parses Salesforce-shaped `/HomeScreenInformation` payloads (local backend mirror).
class HomeSnapshot {
  const HomeSnapshot({
    required this.raw,
    this.customer,
    this.loanApplication,
    this.marketPlace,
    this.loanAccount,
    this.loanAppDetail,
    this.loanRequired = true,
    this.topUpEligible = false,
    this.ekyc = false,
  });

  final Map<String, dynamic> raw;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? loanApplication;
  final Map<String, dynamic>? marketPlace;
  final Map<String, dynamic>? loanAccount;
  final Map<String, dynamic>? loanAppDetail;
  final bool loanRequired;
  final bool topUpEligible;
  final bool ekyc;

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeSnapshot(
      raw: json,
      customer: _firstRecord(json['Customer']),
      loanApplication: _firstRecord(json['LoanApplication']),
      marketPlace: _firstRecord(json['MarketPlace']),
      loanAccount: _firstRecord(json['LoanAccount']),
      loanAppDetail: _firstRecord(json['LoanAppDetail']),
      loanRequired: json['LoanRequired'] != false,
      topUpEligible: json['TopUpEligible'] == true,
      ekyc: json['Ekyc'] == true,
    );
  }

  static Map<String, dynamic>? _firstRecord(dynamic section) {
    if (section is! Map) return null;
    final records = section['records'];
    if (records is! List || records.isEmpty) return null;
    final first = records.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  String? get contractId {
    final fromLoan = loanAccount?['Name']?.toString();
    if (fromLoan != null && fromLoan.isNotEmpty) return fromLoan;
    final nested = marketPlace?['peer__Loan__r'];
    if (nested is Map && nested['Name'] != null) {
      return nested['Name'].toString();
    }
    return marketPlace?['peer__Loan__c']?.toString();
  }

  String get peerStage => marketPlace?['peer__Stage__c']?.toString() ?? '';

  String get loanStatus =>
      loanAccount?['loan__Loan_Status__c']?.toString() ?? '';

  String get disbursalBankStatus =>
      loanAccount?['Disbursal_Bank_Status__c']?.toString() ?? '';

  bool get emailVerified {
    final v = customer?['Email_OTP_Verified__c'];
    return v == true || v == 1 || v == '1' || v == 'true';
  }

  /// Salesforce / local `Disbursal_Bank_Status__c` — null/blank means not transferred.
  bool get transferredToBank => disbursalBankStatus.trim().isNotEmpty;

  bool get hasMarketplace => marketPlace != null;

  bool get hasLoanAccount => loanAccount != null;

  double? get approvedAmount {
    final v =
        marketPlace?['Approved_Loan_Amount__c'] ??
        loanAccount?['loan__Loan_Amount__c'] ??
        loanApplication?['genesis__Loan_Amount__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double? get emiAmount {
    final v = loanAccount?['loan__Amount_to_Current__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  /// Mandate max amount written to bank at origination (`NACH_Amount__c`).
  /// This is already a per-EMI ceiling (emi × 1.05), not a loan total.
  double? get nachAmount {
    final v =
        loanAccount?['NACH_Amount__c'] ?? loanAccount?['loan__Pmt_Amt_Cur__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  int? get remainingEmi => _asInt(loanAccount?['Remaining_EMI__c']);

  /// `loan__Loan_Amount__c` — what RN prints as "Your Loan".
  double? get loanAmount {
    final v = loanAccount?['loan__Loan_Amount__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  int? get totalInstallments =>
      _asInt(loanAccount?['loan__Number_of_Installments__c']);

  /// Monthly EMI for display / Pre-Pay. Prefer contract EMI; NACH is mandate
  /// ceiling only — never divide NACH by tenure (that understates EMI ~3–12×).
  double? get installmentAmount {
    final emi = emiAmount;
    if (emi != null && emi > 0) return emi;
    return nachAmount;
  }

  int get paidInstallments {
    final total = totalInstallments;
    if (total == null || total <= 0) return 0;
    if (loanCompleted) return total;
    final remaining = remainingEmi;
    if (remaining == null) return 0;
    return (total - remaining).clamp(0, total);
  }

  String? get nextInstallmentDate =>
      loanAccount?['loan__Next_Installment_Date__c']?.toString();

  /// RN start date: oldest unpaid due date, else the first installment date.
  DateTime? get installmentStartDate =>
      _asDate(loanAccount?['loan__Oldest_Due_Date__c']) ??
      _asDate(loanAccount?['loan__First_Installment_Date__c']);

  /// Days past `installmentStartDate`; null when nothing is overdue.
  int? get overdueDays {
    final due = installmentStartDate;
    if (due == null || loanCompleted) return null;
    final today = DateTime.now();
    final days = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(due.year, due.month, due.day)).inDays;
    return days > 0 ? days : null;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static DateTime? _asDate(dynamic v) {
    if (v is DateTime) return v;
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  bool get eligibleForReapply {
    final v =
        loanAppDetail?['Eligible_for_reapply__c'] ??
        marketPlace?['Eligible_for_reapply__c'];
    if (v is bool) return v;
    if (v == null || v == '') return false;
    return true;
  }

  bool get loanClosed {
    final stage = peerStage.toLowerCase();
    return loanStatus.toLowerCase().contains('closed') || stage == 'closed';
  }

  bool get loanDisbursed =>
      peerStage.toLowerCase() == 'disbursed' || transferredToBank;

  /// Mirrors RN `repaymentComplete` in `scenes/home/index.js`, minus its
  /// `TopUpEligible` term: that flag is set once and never cleared, so it would
  /// keep claiming the next loan is repaid too. This contract's own status is
  /// the reliable signal. `Remaining_EMI__c` is 0 before disbursal as well (no
  /// schedule yet), so it only counts once the loan is disbursed.
  bool get loanCompleted => loanClosed || (loanDisbursed && remainingEmi == 0);

  /// RN gates "Apply for New Loan" on `LoanRequired`, which the backend sets
  /// only when the marketplace application is `Closed - Obligations met`.
  bool get canApplyForNewLoan =>
      (loanRequired || topUpEligible) && loanCompleted;
}

enum HomeCardKind {
  loading,
  error,
  activeLoan,
  loanCompleted,
  funding,
  cancelled,
  cancelReapply,
  completeProcess,
  creditOffer,
  creditPending,
  creditRejected,
  onboarding,
  idle,
}

class HomeCardResolver {
  const HomeCardResolver();

  /// Mirrors RN `scenes/home/index.js` primary-card cascade for post-offer users.
  /// KYC is done when either `ocr_completed` **or** `vkyc_completed` is set.
  HomeCardKind resolve({
    required HomeSnapshot? home,
    required bool plOrDc,
    required bool enach,
    required bool ocr,
    required bool vkyc,
    required bool bank,
    required bool bankVerified,
    required bool finbit,
    required bool equifax,
    String? creditStatus,
  }) {
    if (home == null) return HomeCardKind.idle;

    final stage = home.peerStage.toLowerCase();
    final kycDone = ocr || vkyc;
    final emailDone = home.emailVerified;
    final transferred = home.transferredToBank;
    final cd = creditStatus?.toUpperCase();

    if (stage == 'canceled' || stage == 'cancelled') {
      return home.eligibleForReapply
          ? HomeCardKind.cancelReapply
          : HomeCardKind.cancelled;
    }

    // RN: PL/DC + missing KYC / email / eNACH → "Disbursal Process" checklist.
    if (plOrDc && (!kycDone || !enach || !emailDone)) {
      return HomeCardKind.completeProcess;
    }

    // RN: all steps done + bank transfer status set → active / disbursed loan UI,
    // swapped for the repayment-complete card once the loan is paid off.
    if (plOrDc && kycDone && enach && emailDone && transferred) {
      return home.loanCompleted
          ? HomeCardKind.loanCompleted
          : HomeCardKind.activeLoan;
    }

    // RN: all steps done + Disbursal_Bank_Status null → "in process of funding".
    // Skip when the latest contract is already repaid — leftover flags must not
    // hide the Apply for New Loan card.
    if (plOrDc &&
        kycDone &&
        enach &&
        emailDone &&
        !transferred &&
        !home.loanCompleted) {
      return HomeCardKind.funding;
    }

    // RN: bank verified + finbit + APP → Home Withdraw / Unlock (before accept).
    if (!plOrDc && bank && bankVerified && finbit) {
      if (cd == 'APP') return HomeCardKind.creditOffer;
      if (cd == 'REF' || cd == 'WIP') return HomeCardKind.creditPending;
      if (cd == 'REJ') return HomeCardKind.creditRejected;
    }

    // Onboarding: equifax done but bank path incomplete.
    // Salaried no longer requires employer before bank (employer is Unlock).
    if (equifax && (!bank || !bankVerified || !finbit)) {
      return HomeCardKind.onboarding;
    }

    // Repaid loan whose offer stage the backend already reset (pl/dc cleared,
    // offer archived): keep congratulating and offering a re-apply instead of
    // falling through to the finished loan's funding card.
    if (home.loanCompleted) {
      return HomeCardKind.loanCompleted;
    }

    if (home.hasLoanAccount || home.hasMarketplace) {
      return HomeCardKind.funding;
    }
    return HomeCardKind.idle;
  }
}
