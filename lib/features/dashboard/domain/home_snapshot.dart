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
    final v = marketPlace?['Approved_Loan_Amount__c'] ??
        loanAccount?['loan__Loan_Amount__c'] ??
        loanApplication?['genesis__Loan_Amount__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double? get emiAmount {
    final v = loanAccount?['loan__Amount_to_Current__c'] ??
        loanAccount?['NACH_Amount__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  /// Mandate max amount written to bank at origination (`NACH_Amount__c`).
  double? get nachAmount {
    final v = loanAccount?['NACH_Amount__c'] ??
        loanAccount?['loan__Pmt_Amt_Cur__c'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  int? get remainingEmi {
    final v = loanAccount?['Remaining_EMI__c'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String? get nextInstallmentDate =>
      loanAccount?['loan__Next_Installment_Date__c']?.toString();

  bool get eligibleForReapply {
    final v = loanAppDetail?['Eligible_for_reapply__c'] ??
        marketPlace?['Eligible_for_reapply__c'];
    if (v is bool) return v;
    if (v == null || v == '') return false;
    return true;
  }
}

enum HomeCardKind {
  loading,
  error,
  activeLoan,
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

    // RN: all steps done + bank transfer status set → active / disbursed loan UI.
    if (plOrDc && kycDone && enach && emailDone && transferred) {
      return HomeCardKind.activeLoan;
    }

    // RN: all steps done + Disbursal_Bank_Status null → "in process of funding".
    if (plOrDc && kycDone && enach && emailDone && !transferred) {
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

    if (home.hasLoanAccount || home.hasMarketplace) {
      return HomeCardKind.funding;
    }
    return HomeCardKind.idle;
  }
}
