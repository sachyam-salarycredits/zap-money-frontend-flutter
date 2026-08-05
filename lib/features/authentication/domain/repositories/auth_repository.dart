import '../../../../core/services/screen_status_resolver.dart';
import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<bool> sendOtp({
    required String mobileNumber,
    String hash,
    String appVersion,
  });

  Future<AuthSession?> verifyOtp({
    required String mobileNumber,
    required String otp,
  });

  Future<ScreenCompletionFlags> fetchScreenFlags(String deviceId);

  Future<ProfileSnapshot?> fetchProfile({
    required String customerId,
    required String deviceId,
  });

  Future<bool> hasStoredSession();

  Future<AuthSession?> readStoredSession();

  /// Clears SF id then refreshes from `/GetSFAccountStatus` (RN login biometric).
  Future<void> refreshSfCustomerIdForBiometricLogin();

  /// RN `VkycResponseCheck` — used on PL/DC resume after OTP / biometric.
  Future<bool> isKycComplete();

  Future<String?> checkAppVersion();
}
