import 'package:flutter_test/flutter_test.dart';
import 'package:zap_money/core/constants/app_routes.dart';
import 'package:zap_money/core/services/screen_status_resolver.dart';

void main() {
  const resolver = ScreenStatusResolver();

  test('enach_completed routes to home', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(enach: true, permission: true),
    );
    expect(route, AppRoutes.home);
  });

  test('ocr_completed routes to enach before later flags', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(ocr: true, personalInfo: true),
    );
    expect(route, AppRoutes.enach);
  });

  test('pl_completed without KYC routes to DigiLocker', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(pl: true),
      userType: 'Student',
      kycComplete: false,
    );
    expect(route, AppRoutes.dkyc);
  });

  test('pl_completed with KYC routes to eNACH', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(pl: true),
      userType: 'Student',
      kycComplete: true,
    );
    expect(route, AppRoutes.enach);
  });

  test('dc_completed without KYC routes to DigiLocker', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(dc: true),
      userType: 'Salaried',
    );
    expect(route, AppRoutes.dkyc);
  });

  test('dc_completed with KYC routes to eNACH', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(dc: true),
      userType: 'Salaried',
      kycComplete: true,
    );
    expect(route, AppRoutes.enach);
  });

  test('pl + KYC + enach still routes to home', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(pl: true, enach: true),
      kycComplete: true,
    );
    expect(route, AppRoutes.home);
  });

  test('equifax with plan 0 routes to rejected', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(equifax: true),
      customerPlan: '0',
    );
    expect(route, AppRoutes.rejected);
  });

  test('equifax routes to location permission (not employer/college)', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(equifax: true),
      userType: 'Salaried',
      customerPlan: '1',
    );
    expect(route, AppRoutes.locationPermission);
  });

  test('equifax student also routes to location permission first', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(equifax: true),
      userType: 'Student',
    );
    expect(route, AppRoutes.locationPermission);
  });

  test('permission only routes to profession', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(permission: true),
    );
    expect(route, AppRoutes.profession);
  });

  test('bankDetails without finbit routes to residence (AA ingest background)', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(
        permission: true,
        personalInfo: true,
        equifax: true,
        employerDetails: true,
        bankDetails: true,
      ),
    );
    expect(route, AppRoutes.residenceAddress);
  });

  test('employer without bank routes to bank account validation', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(
        permission: true,
        personalInfo: true,
        equifax: true,
        employerDetails: true,
      ),
    );
    expect(route, AppRoutes.finbit);
  });

  test('college without bank routes to bank account validation', () {
    final route = resolver.resolve(
      flags: const ScreenCompletionFlags(
        permission: true,
        personalInfo: true,
        equifax: true,
        collegeDetails: true,
      ),
      userType: 'Student',
    );
    expect(route, AppRoutes.finbit);
  });

  test('no flags routes to permission', () {
    final route = resolver.resolve(flags: const ScreenCompletionFlags());
    expect(route, AppRoutes.permission);
  });

  test('fromScreenList parses RN screen_name payloads', () {
    final flags = ScreenCompletionFlags.fromScreenList([
      {'screen_name': 'permissionGranted'},
      {'screen_name': 'enach_completed'},
    ]);
    expect(flags.permission, isTrue);
    expect(flags.enach, isTrue);
  });
}
