import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/otp_screen.dart';
import '../features/authentication/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/app_shell.dart';
import '../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../features/funnel/presentation/screens/offer_screen.dart';
import '../features/funnel/presentation/screens/bank_and_offer_screens.dart';
import '../features/funnel/presentation/screens/document_screen.dart';
import '../features/funnel/presentation/screens/employment_screens.dart';
import '../features/funnel/presentation/screens/equifax_screen.dart';
import '../features/funnel/presentation/screens/location_permission_screen.dart';
import '../features/funnel/presentation/screens/pancard_screen.dart';
import '../features/funnel/presentation/screens/permission_screen.dart';
import '../features/funnel/presentation/screens/personal_info_screen.dart';
import '../features/funnel/presentation/screens/profession_screen.dart';
import '../features/funnel/presentation/screens/referred_screen.dart';
import '../features/kyc/presentation/screens/dkyc_screen.dart';
import '../features/kyc/presentation/screens/email_verification_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/payments/presentation/screens/enach_screen.dart';
import '../features/payments/presentation/screens/enach_upi_screen.dart';
import '../features/loans/presentation/screens/loan_details_screen.dart';
import '../features/profile/presentation/screens/profile_detail_screens.dart';
import '../features/profile/presentation/screens/profile_hub_screen.dart';
import '../features/profile/presentation/screens/salary_details_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  ref.listen<int>(unauthorizedSignalProvider, (previous, next) {
    final ctx = _rootKey.currentContext;
    if (ctx != null) {
      GoRouter.of(ctx).go(AppRoutes.login);
    }
  });

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final mobile = state.extra as String? ?? '';
          return OtpScreen(mobileNumber: mobile);
        },
      ),
      GoRoute(
        path: AppRoutes.permission,
        builder: (context, state) => const PermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.profession,
        builder: (context, state) => const ProfessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.document,
        builder: (context, state) => DocumentScreen(
          userType: state.extra as String?,
        ),
      ),
      GoRoute(
        path: AppRoutes.pancard,
        builder: (context, state) => PancardScreen(
          userType: state.extra as String?,
        ),
      ),
      GoRoute(
        path: AppRoutes.personalInfo,
        builder: (context, state) => PersonalInfoScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.equifax,
        builder: (context, state) => const EquifaxScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationPermission,
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.employerDetails,
        builder: (context, state) => EmployerDetailsScreen(
          isFrom: state.extra is Map
              ? (state.extra as Map)['isFrom']?.toString()
              : state.extra as String?,
        ),
      ),
      GoRoute(
        path: AppRoutes.collegeDetails,
        builder: (context, state) => const CollegeDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bankDetails,
        builder: (context, state) => const BankDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bankStatement,
        builder: (context, state) => BankStatementScreen(
          args: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.finbit,
        builder: (context, state) => FinbitScreen(
          args: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.residenceAddress,
        builder: (context, state) => const ResidenceAddressScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressSelection,
        builder: (context, state) => const ResidenceAddressScreen(),
      ),
      GoRoute(
        path: AppRoutes.waiting,
        builder: (context, state) => const WaitingScreen(),
      ),
      GoRoute(
        path: AppRoutes.offer,
        builder: (context, state) => const OfferScreen(),
      ),
      GoRoute(
        path: AppRoutes.rejected,
        builder: (context, state) => const RejectedScreen(),
      ),
      GoRoute(
        path: AppRoutes.referred,
        builder: (context, state) {
          final status = state.extra is Map
              ? (state.extra as Map)['status']?.toString()
              : state.extra as String?;
          return ReferredScreen(status: status);
        },
      ),
      GoRoute(
        path: AppRoutes.enach,
        builder: (context, state) => const EnachScreen(),
      ),
      GoRoute(
        path: AppRoutes.enachUpi,
        builder: (context, state) => EnachUpiScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        // Legacy /vkyc path now opens DigiLocker (product no longer uses Video KYC).
        path: AppRoutes.vkyc,
        builder: (context, state) => const DkycScreen(),
      ),
      GoRoute(
        path: AppRoutes.dkyc,
        builder: (context, state) => const DkycScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) => EmailVerificationScreen(
          initialEmail: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.profilePersonal,
        builder: (context, state) => ProfilePersonalScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.profileBank,
        builder: (context, state) => ProfileBankScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.profileEmployer,
        builder: (context, state) => ProfileEmployerScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.profileSalary,
        builder: (context, state) => ProfileSalaryScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.profileAddress,
        builder: (context, state) => const ProfileAddressScreen(),
      ),
      GoRoute(
        path: AppRoutes.myLoans,
        builder: (context, state) => MyLoansScreen(
          contractId: state.extra is String ? state.extra as String? : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.loanTransactions,
        builder: (context, state) => LoanTransactionsScreen(
          args: state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.creditScore,
                builder: (context, state) => const CreditScoreTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                // Discount tab reuses Learn (RN parity).
                path: AppRoutes.discount,
                builder: (context, state) => const LearnTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reward,
                builder: (context, state) => const RewardTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.learn,
                builder: (context, state) => const LearnTabScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
