/// Screen completion flag strings — must match RN `ScreenStatus.js`.
class ScreenStatusFlags {
  ScreenStatusFlags._();

  static const permission = 'permissionGranted';
  static const personalInfo = 'personalinfo_completed';
  static const emailVerified = 'email_verified';
  static const equifax = 'equifax_completed';
  static const employerDetails = 'employerdetails_completed';
  static const collegeDetails = 'collegedetails_completed';
  static const bankDetails = 'bankdetails_completed';
  static const bankDetailsVerified = 'bankdetails_verified';
  static const finbit = 'finbit_completed';
  static const addressSelection = 'address_completed';
  static const amountRequest = 'amount_requested';
  static const pl = 'pl_completed';
  static const dc = 'dc_completed';
  static const ocr = 'ocr_completed';
  static const enach = 'enach_completed';
  static const references = 'reference_completed';
  static const vkyc = 'vkyc_completed';
}
