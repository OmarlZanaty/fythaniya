import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps `local_auth` with the app's UX defaults:
/// - Arabic prompt text
/// - Device-credential fallback (PIN/pattern), not biometric-only
/// - A persisted "enabled" toggle in SharedPreferences
/// - Safe no-op on devices without enrolled biometrics
///
/// Uses only the stable core `local_auth` API (LocalAuthentication +
/// AuthenticationOptions) so it builds across local_auth 2.x point versions.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const _enabledKey = 'fyt_biometric_enabled';

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('[Biometric] canUseBiometrics failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Biometric] canUseBiometrics unexpected: $e');
      return false;
    }
  }

  /// String-match on the enum's toString so we don't depend on the
  /// `BiometricType` enum name (which moved between local_auth versions).
  Future<String> bestAvailableLabel() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      final s = list.map((e) => e.toString().toLowerCase()).join(',');
      if (s.contains('face')) return 'الوجه';
      if (s.contains('fingerprint')) return 'البصمة';
      if (s.contains('iris')) return 'القزحية';
      return 'القياس الحيوي';
    } catch (_) { return 'القياس الحيوي'; }
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enabledKey, v);
  }

  /// Shows the system biometric prompt. Returns true if the user authenticated.
  /// Returns false on cancel, lockout, or any error (UI should fall back to password).
  Future<bool> authenticate({String reason = 'تأكيد هويتك للدخول إلى التطبيق'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[Biometric] authenticate failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Biometric] authenticate unexpected: $e');
      return false;
    }
  }
}
