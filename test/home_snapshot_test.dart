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
