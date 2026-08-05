import '../constants/app_routes.dart';
import '../constants/screen_status_flags.dart';

export '../constants/screen_status_flags.dart';

class ScreenCompletionFlags {
  const ScreenCompletionFlags({
    this.permission = false,
    this.personalInfo = false,
    this.equifax = false,
    this.employerDetails = false,
    this.collegeDetails = false,
    this.bankDetails = false,
    this.bankDetailsVerified = false,
    this.finbit = false,
    this.addressSelection = false,
    this.dc = false,
    this.pl = false,
    this.ocr = false,
    this.enach = false,
    this.vkyc = false,
  });

  final bool permission;
  final bool personalInfo;
  final bool equifax;
  final bool employerDetails;
  final bool collegeDetails;
  final bool bankDetails;
  final bool bankDetailsVerified;
  final bool finbit;
  final bool addressSelection;
  final bool dc;
  final bool pl;
  final bool ocr;
  final bool enach;
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
      case ScreenStatusFlags.dc:
        return _copy(dc: true);
      case ScreenStatusFlags.pl:
        return _copy(pl: true);
      case ScreenStatusFlags.ocr:
        return _copy(ocr: true);
      case ScreenStatusFlags.enach:
        return _copy(enach: true);
      case ScreenStatusFlags.vkyc:
        return _copy(vkyc: true);
      default:
        return this;
    }
  }

  ScreenCompletionFlags _copy({
    bool? permission,
    bool? personalInfo,
    bool? equifax,
    bool? employerDetails,
    bool? collegeDetails,
    bool? bankDetails,
    bool? bankDetailsVerified,
    bool? finbit,
    bool? addressSelection,
    bool? dc,
    bool? pl,
    bool? ocr,
    bool? enach,
    bool? vkyc,
  }) {
    return ScreenCompletionFlags(
      permission: permission ?? this.permission,
      personalInfo: personalInfo ?? this.personalInfo,
      equifax: equifax ?? this.equifax,
      employerDetails: employerDetails ?? this.employerDetails,
      collegeDetails: collegeDetails ?? this.collegeDetails,
      bankDetails: bankDetails ?? this.bankDetails,
      bankDetailsVerified: bankDetailsVerified ?? this.bankDetailsVerified,
      finbit: finbit ?? this.finbit,
      addressSelection: addressSelection ?? this.addressSelection,
      dc: dc ?? this.dc,
      pl: pl ?? this.pl,
      ocr: ocr ?? this.ocr,
      enach: enach ?? this.enach,
      vkyc: vkyc ?? this.vkyc,
    );
  }
}

/// Resolves next route using the exact RN OTP / biometric resume ladder order.
class ScreenStatusResolver {
  const ScreenStatusResolver();

  /// [userType] retained for callers; after equifax all types go to location.
  /// When PL/DC is done, [kycComplete] gates DigiLocker vs home — RN biometric
  /// called `VkycResponseCheck` and sent incomplete KYC to vkyc/Dkyc; Flutter
  /// uses DigiLocker (`dkyc`) for all user types.
  String resolve({
    required ScreenCompletionFlags flags,
    String? userType,
    String customerPlan = '1',
    bool kycComplete = false,
  }) {
    if (flags.enach) return AppRoutes.home;
    if (flags.ocr) return AppRoutes.enach;
    // RN biometric: pl/dc → VkycResponseCheck → home or vkyc/Dkyc.
    if (flags.pl || flags.dc) {
      if (kycComplete) return AppRoutes.home;
      return AppRoutes.dkyc;
    }
    if (flags.addressSelection) return AppRoutes.waiting;
    if (flags.finbit && flags.bankDetails) return AppRoutes.residenceAddress;
    if (flags.bankDetails) return AppRoutes.bankStatement;
    if (flags.collegeDetails || flags.employerDetails) {
      return AppRoutes.bankDetails;
    }
    if (flags.equifax) {
      if (customerPlan == '0') return AppRoutes.rejected;
      // RN: after equifax → location permission, then bank/college.
      return AppRoutes.locationPermission;
    }
    if (flags.personalInfo) return AppRoutes.equifax;
    if (flags.permission) return AppRoutes.profession;
    return AppRoutes.permission;
  }
}
