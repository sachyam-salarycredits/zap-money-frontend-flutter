/// GoRouter path constants.
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/otp';

  // Onboarding funnel
  static const permission = '/permission';
  static const profession = '/profession';
  static const document = '/document';
  static const pancard = '/pancard';
  static const personalInfo = '/personal-info';
  static const equifax = '/equifax';
  static const locationPermission = '/location-permission';
  static const employerDetails = '/employer-details';
  static const collegeDetails = '/college-details';
  static const bankDetails = '/bank-details';
  static const bankStatement = '/bank-statement';
  static const finbit = '/finbit';
  static const residenceAddress = '/residence-address';
  static const addressSelection = '/address-selection';
  static const waiting = '/waiting';
  static const offer = '/offer';
  static const rejected = '/rejected';
  static const referred = '/referred';
  static const enach = '/enach';
  static const enachUpi = '/enach/upi';
  static const vkyc = '/vkyc';
  static const dkyc = '/dkyc';
  static const emailVerification = '/email-verification';

  // Profile
  static const profile = '/profile';
  static const profilePersonal = '/profile/personal';
  static const profileBank = '/profile/bank';
  static const profileEmployer = '/profile/employer';
  static const profileSalary = '/profile/salary';
  static const profileAddress = '/profile/address';
  static const myLoans = '/my-loans';
  static const loanTransactions = '/loan-transactions';

  // Main app shell
  static const app = '/app';
  static const home = '/app/home';
  static const creditScore = '/app/credit';
  static const discount = '/app/discount';
  static const learn = '/app/learn';
  static const reward = '/app/reward';
}
