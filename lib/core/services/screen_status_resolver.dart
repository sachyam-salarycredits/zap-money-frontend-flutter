import '../constants/app_routes.dart';
import '../constants/screen_status_flags.dart';

export '../constants/screen_status_flags.dart';

class ScreenCompletionFlags {
  const ScreenCompletionFlags({
    this.permission = false,
    this.personalInfo = false,
    this.emailVerified = false,
    this.equifax = false,
    this.employerDetails = false,
    this.collegeDetails = false,
    this.bankDetails = false,
    this.bankDetailsVerified = false,
    this.finbit = false,
    this.addressSelection = false,
    this.amountRequest = false,
    this.dc = false,
    this.pl = false,
    this.ocr = false,
    this.enach = false,
    this.references = false,
    this.vkyc = false,
  });

  final bool permission;
  final bool personalInfo;
  final bool emailVerified;
  final bool equifax;
  final bool employerDetails;
  final bool collegeDetails;
  final bool bankDetails;
  final bool bankDetailsVerified;
  final bool finbit;
  final bool addressSelection;
  final bool amountRequest;
  final bool dc;
  final bool pl;
  final bool ocr;
  final bool enach;
  final bool references;
  final bool vkyc;

  factory ScreenCompletionFlags.fromScreenList(List<dynamic> screens) {
    var flags = const ScreenCompletionFlags();
    for (final item in screens) {
      final name = item is Map ? item['screen_name'] as String? : null;
      if (name == null) continue;
      flags = flags._withFlag(name);
    }
    return flags;
  }

  ScreenCompletionFlags _withFlag(String name) {
    switch (name) {
      case ScreenStatusFlags.permission:
        return _copy(permission: true);
      case ScreenStatusFlags.personalInfo:
        return _copy(personalInfo: true);
      case ScreenStatusFlags.emailVerified:
        return _copy(emailVerified: true);
      case ScreenStatusFlags.equifax:
        return _copy(equifax: true);
      case ScreenStatusFlags.employerDetails:
        return _copy(employerDetails: true);
      case ScreenStatusFlags.collegeDetails:
        return _copy(collegeDetails: true);
      case ScreenStatusFlags.bankDetails:
        return _copy(bankDetails: true);
      case ScreenStatusFlags.bankDetailsVerified:
        return _copy(bankDetailsVerified: true);
      case ScreenStatusFlags.finbit:
        return _copy(finbit: true);
      case ScreenStatusFlags.addressSelection:
        return _copy(addressSelection: true);
      case ScreenStatusFlags.amountRequest:
        return _copy(amountRequest: true);
      case ScreenStatusFlags.dc:
        return _copy(dc: true);
      case ScreenStatusFlags.pl:
        return _copy(pl: true);
      case ScreenStatusFlags.ocr:
        return _copy(ocr: true);
      case ScreenStatusFlags.enach:
        return _copy(enach: true);
      case ScreenStatusFlags.references:
        return _copy(references: true);
      case ScreenStatusFlags.vkyc:
        return _copy(vkyc: true);
      default:
        return this;
    }
  }

  ScreenCompletionFlags _copy({
    bool? permission,
    bool? personalInfo,
    bool? emailVerified,
    bool? equifax,
    bool? employerDetails,
    bool? collegeDetails,
    bool? bankDetails,
    bool? bankDetailsVerified,
    bool? finbit,
    bool? addressSelection,
    bool? amountRequest,
    bool? dc,
    bool? pl,
    bool? ocr,
    bool? enach,
    bool? references,
    bool? vkyc,
  }) {
    return ScreenCompletionFlags(
      permission: permission ?? this.permission,
      personalInfo: personalInfo ?? this.personalInfo,
      emailVerified: emailVerified ?? this.emailVerified,
      equifax: equifax ?? this.equifax,
      employerDetails: employerDetails ?? this.employerDetails,
      collegeDetails: collegeDetails ?? this.collegeDetails,
      bankDetails: bankDetails ?? this.bankDetails,
      bankDetailsVerified: bankDetailsVerified ?? this.bankDetailsVerified,
      finbit: finbit ?? this.finbit,
      addressSelection: addressSelection ?? this.addressSelection,
      amountRequest: amountRequest ?? this.amountRequest,
      dc: dc ?? this.dc,
      pl: pl ?? this.pl,
      ocr: ocr ?? this.ocr,
      enach: enach ?? this.enach,
      references: references ?? this.references,
      vkyc: vkyc ?? this.vkyc,
    );
  }
}

/// Resolves next route using the exact RN OTP / biometric resume ladder order.
class ScreenStatusResolver {
  const ScreenStatusResolver();

  /// [userType] retained for callers; after equifax all types go to location.
  /// When PL/DC is done, [kycComplete] gates DigiLocker vs Home. eNACH is
  /// collected after the loan is funded, not before funding starts.
  String resolve({
    required ScreenCompletionFlags flags,
    String? userType,
    String customerPlan = '1',
    bool kycComplete = false,
  }) {
    final kycDone = kycComplete || flags.ocr || flags.vkyc;
    if (flags.enach || flags.references) return AppRoutes.home;
    if (flags.pl || flags.dc) {
      if (kycDone) return AppRoutes.home;
      return AppRoutes.dkyc;
    }
    if (flags.amountRequest && !(flags.pl || flags.dc)) return AppRoutes.home;
    if (flags.addressSelection) return AppRoutes.waiting;
    if (flags.finbit && flags.bankDetails) return AppRoutes.residenceAddress;
    // bankDetails is set only after Finarkein consent ACTIVE (not mid-OTP quit).
    // Continue residence while ingest finishes; do not reopen WebView.
    if (flags.bankDetails) return AppRoutes.residenceAddress;
    if (flags.collegeDetails || flags.employerDetails) {
      return AppRoutes.finbit;
    }
    if (flags.equifax) {
      if (customerPlan == '0') return AppRoutes.rejected;
      // After equifax → location, then Bank account Validation (Finarkein).
      return AppRoutes.locationPermission;
    }
    // Email is verified right after Aadhaar/email are saved, before DigiLocker.
    if (flags.personalInfo && !flags.emailVerified && !kycDone) {
      return AppRoutes.emailVerification;
    }
    if (flags.personalInfo && !kycDone) return AppRoutes.dkyc;
    if (flags.personalInfo) return AppRoutes.equifax;
    if (flags.permission) return AppRoutes.profession;
    return AppRoutes.permission;
  }
}
