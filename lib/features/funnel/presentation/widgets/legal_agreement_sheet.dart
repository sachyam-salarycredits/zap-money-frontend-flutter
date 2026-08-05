import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';

/// RN `scenes/LegalAgreement` — scrollable borrower T&Cs modal.
Future<void> showLegalAgreementSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF2A0A5C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    "ZAP Money's\nTerms and Conditions",
                    textAlign: TextAlign.center,
                    style: AppTypography.headline(size: 20),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _section(
                        '1',
                        'IMPORTANT NOTICE',
                        'PLEASE READ THE FOLLOWING BEFORE PROCEEDING WITH YOUR REGISTRATION:\n\n'
                            'THESE TERMS AND CONDITIONS ARE THE TERMS UPON WHICH YOU WILL '
                            'PARTICIPATE IN THE MONEXO PLATFORM IN THE EVENT THAT YOU ARE '
                            'ACCEPTED BY MONEXO AS A BORROWER.\n\n'
                            'BY YOU EITHER CLICKING A BUTTON/CHECKING A BOX INDICATING YOUR '
                            'ACCEPTANCE, OR BY REGISTERING ON THE PLATFORM, AND/OR BY EXECUTING '
                            'ANY DOCUMENT THAT REFERENCES THIS AGREEMENT AND/OR BY ACCESSING '
                            'AND/OR USING THE APPS, YOU HEREBY EXPRESSLY ACKNOWLEDGE AND AGREE TO '
                            'BE BOUND BY THIS AGREEMENT, POLICIES AND GUIDELINES INCORPORATED BY '
                            'REFERENCE IN THIS AGREEMENT AND ANY FUTURE AMENDMENTS AND ADDITIONS '
                            'TO THIS AGREEMENT AS PUBLISHED FROM TIME TO TIME ON THE MONEXO '
                            'PLATFORM. SHOULD YOU DISAGREE WITH ANY OF THE TERMS & CONDITIONS '
                            'STIPULATED HEREIN (IN PART OR IN ENTIRETY), YOU ARE HEREBY DIRECTED '
                            'TO REFRAIN FROM ACCESSING, REGISTERING, LOGGING-IN ON THE PLATFORM '
                            'OR HAVE ANY ACCESS TO OUR SERVICES.',
                      ),
                      _section(
                        '2',
                        'DEFINITIONS',
                        'In these Terms, unless the context otherwise requires, the following '
                            'words and expressions shall have the following meanings:\n\n'
                            '• “Apps” means the mobile applications made available by MONEXO.\n'
                            '• “Borrower” means you, the person applying for a loan on the Platform.\n'
                            '• “Financing Documents” means the loan agreement and related documents.\n'
                            '• “Platform” means the MONEXO / ZAP Money lending marketplace.\n'
                            '• “Relevant Transaction” means the loan or credit facility you request.',
                      ),
                      _section(
                        '3',
                        'ELIGIBILITY & REGISTRATION',
                        'You represent that you are legally competent to contract, that all '
                            'information you provide is true and complete, and that you will keep '
                            'your credentials secure. MONEXO may refuse, suspend, or terminate '
                            'access if information is false or incomplete.',
                      ),
                      _section(
                        '4',
                        'LOAN REQUEST & APPROVAL',
                        'Submitting a request does not guarantee approval. Any offer is subject '
                            'to credit assessment, KYC, mandate setup, and applicable laws. Loan '
                            'amount, tenure, interest, and fees shown in the App form part of your '
                            'acceptance when you apply.',
                      ),
                      _section(
                        '5',
                        'FEES, INTEREST & REPAYMENT',
                        'Interest, processing fees, and other charges may apply as disclosed '
                            'before you accept an offer. You agree to repay installments on the '
                            'due dates via the mandate / payment methods you authorize.',
                      ),
                      _section(
                        '6',
                        'KYC, MANDATES & DATA',
                        'You authorize collection and verification of KYC, bank, employment, and '
                            'bureau data as needed to underwrite and service the loan. You consent '
                            'to eNACH / UPI mandate creation for EMI collection where applicable.',
                      ),
                      _section(
                        '7',
                        'ACCEPTANCE',
                        'Checking “I agree with the Legal agreements” and tapping Apply Now '
                            'constitutes your electronic acceptance of these Terms and the '
                            'Financing Documents presented for your offer.',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ZapSubmitButton(
                    title: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _section(String index, String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accentMint, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            index,
            style: AppTypography.body(size: 12, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.accentMint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: AppTypography.body(size: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
