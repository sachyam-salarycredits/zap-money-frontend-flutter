import 'package:flutter_test/flutter_test.dart';
import 'package:zap_money/features/dashboard/domain/home_snapshot.dart';

void main() {
  const resolver = HomeCardResolver();

  test('HomeSnapshot parses SF-shaped records', () {
    final snap = HomeSnapshot.fromJson({
      'Customer': {
        'records': [
          {'Email_OTP_Verified__c': true, 'Customer_ID__c': '61'},
        ],
      },
      'MarketPlace': {
        'records': [
          {
            'peer__Stage__c': 'Disbursed',
            'Approved_Loan_Amount__c': 50000,
            'peer__Loan__r': {'Name': 'LC-61'},
          },
        ],
      },
      'LoanAccount': {
        'records': [
          {
            'Name': 'LC-61',
            'loan__Loan_Amount__c': 50000,
            'Remaining_EMI__c': 3,
            'Disbursal_Bank_Status__c': 'Sent',
            'loan__Loan_Status__c': 'Active',
          },
        ],
      },
      'LoanRequired': false,
      'TopUpEligible': false,
      'Ekyc': false,
    });

    expect(snap.emailVerified, isTrue);
    expect(snap.transferredToBank, isTrue);
    expect(snap.contractId, 'LC-61');
    expect(snap.approvedAmount, 50000);
    expect(snap.remainingEmi, 3);
    expect(snap.peerStage, 'Disbursed');
  });

  test('emailVerified accepts truthy 1', () {
    final snap = HomeSnapshot.fromJson({
      'Customer': {
        'records': [
          {'Email_OTP_Verified__c': 1},
        ],
      },
    });
    expect(snap.emailVerified, isTrue);
  });

  test('incomplete enach shows disbursal checklist', () {
    final kind = resolver.resolve(
      home: HomeSnapshot.fromJson({
        'Customer': {
          'records': [
            {'Email_OTP_Verified__c': true},
          ],
        },
      }),
      plOrDc: true,
      enach: false,
      ocr: false,
      vkyc: true,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
    );
    expect(kind, HomeCardKind.completeProcess);
  });

  test('vkyc without ocr still counts as KYC done → funding', () {
    final kind = resolver.resolve(
      home: HomeSnapshot.fromJson({
        'Customer': {
          'records': [
            {'Email_OTP_Verified__c': true},
          ],
        },
        'MarketPlace': {
          'records': [
            {'peer__Stage__c': 'In Funding'},
          ],
        },
        'LoanAccount': {
          'records': [
            {'Disbursal_Bank_Status__c': ''},
          ],
        },
      }),
      plOrDc: true,
      enach: true,
      ocr: false,
      vkyc: true,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
    );
    expect(kind, HomeCardKind.funding);
  });

  test('all steps + disbursal status → active loan', () {
    final kind = resolver.resolve(
      home: HomeSnapshot.fromJson({
        'Customer': {
          'records': [
            {'Email_OTP_Verified__c': true},
          ],
        },
        'LoanAccount': {
          'records': [
            {'Disbursal_Bank_Status__c': 'Sent'},
          ],
        },
      }),
      plOrDc: true,
      enach: true,
      ocr: true,
      vkyc: false,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
    );
    expect(kind, HomeCardKind.activeLoan);
  });

  HomeSnapshot disbursedSnapshot(Map<String, dynamic> loanAccount,
      {bool loanRequired = true, bool topUpEligible = false}) {
    return HomeSnapshot.fromJson({
      'Customer': {
        'records': [
          {'Email_OTP_Verified__c': true},
        ],
      },
      'LoanAccount': {
        'records': [
          {'Disbursal_Bank_Status__c': 'Sent', ...loanAccount},
        ],
      },
      'LoanRequired': loanRequired,
      'TopUpEligible': topUpEligible,
    });
  }

  HomeCardKind resolveDisbursed(HomeSnapshot home) => resolver.resolve(
        home: home,
        plOrDc: true,
        enach: true,
        ocr: true,
        vkyc: false,
        bank: true,
        bankVerified: true,
        finbit: true,
        equifax: true,
      );

  test('disbursed loan with zero remaining EMIs → repayment complete', () {
    final home = disbursedSnapshot({'Remaining_EMI__c': 0});
    expect(home.loanCompleted, isTrue);
    expect(home.canApplyForNewLoan, isTrue);
    expect(resolveDisbursed(home), HomeCardKind.loanCompleted);
  });

  test('closed loan status → repayment complete', () {
    final home = disbursedSnapshot({
      'Remaining_EMI__c': 2,
      'loan__Loan_Status__c': 'Closed - Obligations met',
    });
    expect(home.loanCompleted, isTrue);
    expect(resolveDisbursed(home), HomeCardKind.loanCompleted);
  });

  test('top-up eligibility alone does not mark a running loan as repaid', () {
    // The flag is set at closure and never cleared, so it must not override the
    // next loan's own status.
    final home = disbursedSnapshot({'Remaining_EMI__c': 2}, topUpEligible: true);
    expect(home.loanCompleted, isFalse);
    expect(resolveDisbursed(home), HomeCardKind.activeLoan);
  });

  test('top-up eligibility lets a repaid loan re-apply', () {
    final home = disbursedSnapshot(
      {'Remaining_EMI__c': 0},
      loanRequired: false,
      topUpEligible: true,
    );
    expect(home.loanCompleted, isTrue);
    expect(home.canApplyForNewLoan, isTrue);
  });

  test('zero remaining EMIs before disbursal is not repayment complete', () {
    final home = HomeSnapshot.fromJson({
      'Customer': {
        'records': [
          {'Email_OTP_Verified__c': true},
        ],
      },
      'LoanAccount': {
        'records': [
          {'Disbursal_Bank_Status__c': '', 'Remaining_EMI__c': 0},
        ],
      },
    });
    expect(home.loanCompleted, isFalse);
    expect(resolveDisbursed(home), HomeCardKind.funding);
  });

  test('repaid loan still open on marketplace cannot re-apply', () {
    final home =
        disbursedSnapshot({'Remaining_EMI__c': 0}, loanRequired: false);
    expect(home.loanCompleted, isTrue);
    expect(home.canApplyForNewLoan, isFalse);
  });

  test('installment progress and EMI facts come from the contract', () {
    final home = disbursedSnapshot({
      'loan__Loan_Amount__c': 60000,
      'loan__Amount_to_Current__c': 5500,
      'NACH_Amount__c': 5775,
      'loan__Number_of_Installments__c': 12,
      'Remaining_EMI__c': 9,
      'loan__First_Installment_Date__c': '2026-01-10',
    });

    expect(home.loanAmount, 60000);
    expect(home.totalInstallments, 12);
    expect(home.paidInstallments, 3);
    expect(home.installmentAmount, 5500);
    expect(home.nachAmount, 5775);
    expect(home.installmentStartDate, DateTime(2026, 1, 10));
  });

  test('installmentAmount does not divide NACH by tenure', () {
    final home = disbursedSnapshot({
      'NACH_Amount__c': 1092,
      'loan__Number_of_Installments__c': 3,
    });
    expect(home.installmentAmount, 1092);
  });

  test('repaid loan shows every installment as paid', () {
    final home = disbursedSnapshot({
      'loan__Number_of_Installments__c': 6,
      'Remaining_EMI__c': 0,
    });
    expect(home.paidInstallments, 6);
  });

  test('overdue days count past the oldest due date, and stop once repaid', () {
    final overdue = disbursedSnapshot({
      'Remaining_EMI__c': 4,
      'loan__Oldest_Due_Date__c': DateTime.now()
          .subtract(const Duration(days: 5))
          .toIso8601String(),
    });
    expect(overdue.overdueDays, 5);

    final upcoming = disbursedSnapshot({
      'Remaining_EMI__c': 4,
      'loan__Oldest_Due_Date__c':
          DateTime.now().add(const Duration(days: 5)).toIso8601String(),
    });
    expect(upcoming.overdueDays, isNull);

    final repaid = disbursedSnapshot({
      'Remaining_EMI__c': 0,
      'loan__Oldest_Due_Date__c': DateTime.now()
          .subtract(const Duration(days: 5))
          .toIso8601String(),
    });
    expect(repaid.overdueDays, isNull);
  });

  test('repaid loan with the offer stage reset still congratulates', () {
    // Backend closure clears pl/dc and archives the offer, so there is no
    // credit decision yet — this must not fall through to the funding card.
    final kind = resolver.resolve(
      home: disbursedSnapshot({'Remaining_EMI__c': 0}),
      plOrDc: false,
      enach: false,
      ocr: true,
      vkyc: false,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
    );
    expect(kind, HomeCardKind.loanCompleted);
  });

  test('repaid loan with leftover flags does not show funding', () {
    // Closed-obligations without a bank transfer status would otherwise hit the
    // funding branch when stale pl/dc/enach flags remain.
    final home = HomeSnapshot.fromJson({
      'Customer': {
        'records': [
          {'Email_OTP_Verified__c': true},
        ],
      },
      'LoanAccount': {
        'records': [
          {
            'Remaining_EMI__c': 0,
            'loan__Loan_Status__c': 'Closed - Obligations met',
          },
        ],
      },
      'LoanRequired': true,
      'TopUpEligible': true,
    });
    final kind = resolver.resolve(
      home: home,
      plOrDc: true,
      enach: true,
      ocr: true,
      vkyc: false,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
    );
    expect(home.loanCompleted, isTrue);
    expect(kind, HomeCardKind.loanCompleted);
  });

  test('a fresh approved offer wins over the repaid loan card', () {
    final kind = resolver.resolve(
      home: disbursedSnapshot({'Remaining_EMI__c': 0}),
      plOrDc: false,
      enach: false,
      ocr: true,
      vkyc: false,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
      creditStatus: 'APP',
    );
    expect(kind, HomeCardKind.creditOffer);
  });

  test('bank verified + APP without PL/DC → credit offer', () {
    final kind = resolver.resolve(
      home: HomeSnapshot.fromJson({
        'Customer': {
          'records': [
            {'Email_OTP_Verified__c': false},
          ],
        },
      }),
      plOrDc: false,
      enach: false,
      ocr: false,
      vkyc: false,
      bank: true,
      bankVerified: true,
      finbit: true,
      equifax: true,
      creditStatus: 'APP',
    );
    expect(kind, HomeCardKind.creditOffer);
  });

  test('equifax without bank → onboarding even without employer', () {
    final kind = resolver.resolve(
      home: HomeSnapshot.fromJson({}),
      plOrDc: false,
      enach: false,
      ocr: false,
      vkyc: false,
      bank: false,
      bankVerified: false,
      finbit: false,
      equifax: true,
    );
    expect(kind, HomeCardKind.onboarding);
  });
}
