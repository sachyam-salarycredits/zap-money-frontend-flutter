import '../../../../core/services/screen_status_resolver.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  SendOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<bool> call(
    String mobileNumber, {
    String hash = '',
    String appVersion = '',
  }) {
    return _repository.sendOtp(
      mobileNumber: mobileNumber,
      hash: hash,
      appVersion: appVersion,
    );
  }
}

class VerifyOtpUseCase {
  VerifyOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthSession?> call({
    required String mobileNumber,
    required String otp,
  }) {
    return _repository.verifyOtp(mobileNumber: mobileNumber, otp: otp);
  }
}

class ResolvePostLoginRouteUseCase {
  ResolvePostLoginRouteUseCase(
    this._repository, {
    this.resolver = const ScreenStatusResolver(),
  });

  final AuthRepository _repository;
  final ScreenStatusResolver resolver;

  Future<String> call(AuthSession session) async {
    final flags = await _repository.fetchScreenFlags(session.deviceId);
    ProfileSnapshot? profile;
    if (session.customerId.isNotEmpty) {
      profile = await _repository.fetchProfile(
        customerId: session.customerId,
        deviceId: session.deviceId,
      );
    }

    // RN biometric/OTP: on pl/dc call VkycResponseCheck before navigating.
    var kycComplete = false;
    if (flags.pl || flags.dc) {
      kycComplete = await _repository.isKycComplete();
    }

    return resolver.resolve(
      flags: flags,
      userType: profile?.userType ?? session.userType,
      customerPlan: profile?.customerPlan ?? '1',
      kycComplete: kycComplete,
    );
  }
}
