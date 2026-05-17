import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin-side biometric wrapper. Uses only the stable core `local_auth` API
/// (LocalAuthentication + AuthenticationOptions) — no per-platform message
/// classes, so it builds cleanly across local_auth 2.x point versions.
class AdminBiometricService {
  AdminBiometricService._();
  static final AdminBiometricService instance = AdminBiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const _enabledKey = 'fyt_admin_biometric_enabled';

  /// True if the hardware exists and the user has at least one biometric enrolled.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('[AdminBiometric] canUseBiometrics failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AdminBiometric] canUseBiometrics unexpected: $e');
      return false;
    }
  }

  /// Pick the strongest available biometric for the UI subtitle.
  /// Uses string matching on the enum's toString so we don't depend on the
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

  /// Shows the system biometric prompt. Returns true on success, false on
  /// cancel/error. We allow the device-credential fallback (PIN/pattern) so
  /// users without enrolled biometrics can still pass.
  Future<bool> authenticate({String reason = 'تأكيد هويتك للدخول إلى لوحة الإدارة'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // allow PIN/pattern as a fallback
          stickyAuth: true,       // survive app backgrounding during the prompt
          useErrorDialogs: true,  // let the system render hardware-error UI
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[AdminBiometric] authenticate failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AdminBiometric] authenticate unexpected: $e');
      return false;
    }
  }
}
