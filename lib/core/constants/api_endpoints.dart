import 'app_config.dart';

/// Endpoint catalog mirrored from RN `src/constants/api.js`.
/// Do not invent paths; preserve trailing slashes exactly.
class ApiEndpoints {
  ApiEndpoints._();

  static String get url => AppConfig.baseUrl;
  static String get monexoBaseUrl => AppConfig.monexoGatewayUrl;
  static String get monexoSecurityBaseUrl => AppConfig.securityBaseUrl;

  static String get apiPythonService => '$monexoBaseUrl/gateway/newmapi';
  static String get apiPhpService => '$monexoBaseUrl/gateway/newapi';

  // Auth
  static String get validateDevice => '$url/Register_api/';
  static String get verifyOtp => '$url/login_api/';
  static String get logoutApi => '$url/logout_api/';
  static String get generateRefreshToken =>
      '$monexoSecurityBaseUrl/v1/oauth/generate-token';
  static String get userLogout => logoutApi;

  // Session / funnel
  static String get getScreenCompletionflags => '$url/ScreenStatus';
  static String get screenCompletionflags => '$url/UpdateScreenStatus';
  static String get getProfileInfo => '$url/getProfileInfo/';
  static String get updateVersion => '$url/getBuildVersion';
  static String get vkycResponseCheck => '$url/VkycResponseCheck';

  // Home / loan
  static String get homeScreenInformation => '$url/HomeScreenInformation';
  static String get loanStatus => '$url/LoanStatus';
  static String get loanContractPdf => '$url/Loan-Contract-PDF';
  static String get cashfreeEmiPayment => '$url/CashfreeEmiPayment';
  static String get cashfreeEmiPaymentSuccess =>
      '$url/cashfree-emi-payment-success';
  static String get customerInformation => '$url/customerInformation';
  static String get getSFAccountStatus => '$url/GetSFAccountStatus';
  static String get permissionDataStore => '$apiPhpService/permissionDataStore';
  static String get storeCustomerDeviceLocation =>
      '$url/StoreCustomerDeviceLocation';

  // Profile / KYC prep
  static String get storeCustomerInformation =>
      '$url/Store_customer_information/';
  static String get checkCustomerUniqueness => '$url/CheckCustomerUniqueness';
  static String get panDetails => '$url/PanDetails';
  static String get pullCreditBureau => '$url/pullCreditBureau';
  static String get validatescore => '$url/validatescore';
  static String get pullEquifaxProfile => '$url/pullEquifaxProfile';
  static String get getBureauConsentStatus => '$url/getBureauConsentStatus';
  static String get sendBureauConsentOtp => '$url/sendBureauConsentOtp';
  static String get verifyBureauConsentOtp => '$url/verifyBureauConsentOtp';
  static String get storeBankInfo => '$url/StoreBankInfo';
  static String get getBankAccountInformation =>
      '$url/GetBankAccountInformation';
  static String get getIfscInfo => '$url/getbankaccountinfo/';
  static String get storeEmpInfo => '$url/StoreEmpInfo';
  static String get storeOfficeAddress => '$url/StoreOfficeAddress/';
  static String get saveDocument => '$url/save_document';
  static String get getProfileIcon => '$url/getProfileIcon';
  static String get storeAddressInfo => '$url/StoreAddressInfo';
  static String get getLocalities => '$url/get_localitie/';
  static String get getSubLocalities => '$url/get_sublocalitie/';
  static String get fetchCity => '$apiPythonService/addressAutofill/getCity';
  static String get creditDecision => '$url/CreditDecision';
  static String get getCreditDecisionInformation =>
      '$url/GetCreditDecisionInformation';
  static String get submitLoanAmountRequest => '$url/SubmitLoanAmountRequest';
  static String get storeFinalOfferSelection => '$url/StoreFinalOfferSelection';
  static String get getFinalOfferSelection => '$url/GetFinalOfferSelection';
  static String get storeOfferSelection => '$url/StoreOfferSelection';
  static String get calculateEmi => '$url/calculateEmi';
  static String get monexoFees => '$url/MonexoFees';

  // Profile / customer
  static String get getCustomerInfo => '$url/getCustomerInfo';
  static String get verifyUserEmail => '$url/verify_user_email/';

  // KYC
  static String get createKycLink => '$url/createKycLink';
  static String get digilockerCreateUrl => '$url/digilockerCreateUrl';
  static String get digilockerStatus => '$url/digilockerStatus';
  static String get digilockerComplete => '$url/digilockerComplete';
  static String get uploadDkycResponse => '$url/dkycFrontendResponse';
  static String get esignStatus => '$url/EsignStatus';
  static String get saveReferenceNumber => '$url/save_reference_number';
  static String get getLoanReferences => '$url/GetLoanReferences';

  // eNACH / UPI mandate
  static String get getEnachInformation => '$url/GetENACHInformation';
  static String get enachBanks => '$url/enachBanks';
  static String get enachSourceIdCreation => '$url/enachSourceIdCreation';
  static String get checkSourceStatus => '$url/checkSourceStatus';
  static String get storeEmiInformation => '$url/StoreEMIInformation';
  static String get upiConfigStatus => '$url/upi_config_status/';
  static String get validateVpa => '$url/validate-vpa/';
  static String get createMandate => '$url/create-mandate/';
  static String get upiCurrentStatus => '$url/upi_current_status/';

  // Finarkein AA (Phase A — replaces Finbit bank journey)
  static String get finarkeinConsentInitiate =>
      '$url/api/finarkein/consent/initiate/';
  static String finarkeinRunStatus(String requestId) =>
      '$url/api/finarkein/runs/$requestId/';
  static String finarkeinRunSync(String requestId) =>
      '$url/api/finarkein/runs/$requestId/sync/';

  // Legacy Finbit endpoints (retired when MONEXO_BANK_ANALYTICS_PROVIDER=finarkein)
  static String get getFinbitUrl => '$url/finbitTokenGeneration';
  static String get finbitBankVerification => '$url/finbitBankVerification';
  static String get uploadFinbitBankStatement =>
      '$url/uploadFinbitBankStatement';
  static String get finbitUploadStatement => '$url/finbitUploadStatement';
}
