import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Device unlock for skip-OTP resume — mirrors RN `LocalAuthentication.js`
/// (`fallbackToPasscode: true` + fingerprint / Face ID prompt).
class BiometricService {
  BiometricService({LocalAuthentication? localAuth})
      : _auth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static const fingerprintReason =
      'Scan your Fingerprint on the device scanner to continue';
  static const faceIdReason = 'Scan your Face on the device to continue';

  Future<bool> canCheckBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      // PIN/passcode fallback (RN `fallbackToPasscode`) — device support is enough.
      final canCheck = await _auth.canCheckBiometrics;
      if (canCheck) return true;
      return supported;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('BiometricService.canCheckBiometrics failed: $e\n$st');
      }
      return false;
    }
  }

  Future<String> authReason() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face) ||
          types.contains(BiometricType.iris)) {
        return faceIdReason;
      }
    } catch (_) {}
    return fingerprintReason;
  }

  /// Distinguishes cancel vs hard failure via [BiometricAuthResult].
  Future<BiometricAuthResult> authenticate({String? reason}) async {
    try {
      final localizedReason = reason ?? await authReason();
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          // Match RN LocalAuth `fallbackToPasscode: true`.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return BiometricAuthResult(success: ok, cancelled: !ok);
    } on PlatformException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'BiometricService.authenticate PlatformException '
          'code=${e.code} message=${e.message}\n$st',
        );
      }
      final code = e.code.toLowerCase();
      final isCancel = code == 'usercancel' ||
          code == 'usercanceled' ||
          code == 'systemcancel' ||
          (e.message?.toLowerCase().contains('cancel') ?? false);
      return BiometricAuthResult(
        success: false,
        cancelled: isCancel,
        errorMessage: isCancel
            ? null
            : (e.message ?? 'Biometric authentication failed (${e.code})'),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('BiometricService.authenticate failed: $e\n$st');
      }
      return BiometricAuthResult(
        success: false,
        cancelled: false,
        errorMessage: e.toString(),
      );
    }
  }
}

class BiometricAuthResult {
  const BiometricAuthResult({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
  });

  final bool success;
  final bool cancelled;
  final String? errorMessage;
}
