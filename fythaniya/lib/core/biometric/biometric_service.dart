import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps `local_auth` with the app's UX defaults:
/// - Arabic prompts
/// - Strong (device-credential fallback) authentication
/// - A persisted "enabled" toggle stored in SharedPreferences
/// - Safe no-op on simulators / devices without enrolled biometrics
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const _enabledKey = 'fyt_biometric_enabled';

  /// True if the device hardware + enrollment can perform biometric auth right now.
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

  /// Human-readable label of the strongest available biometric (used in the toggle subtitle).
  Future<String> bestAvailableLabel() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      if (list.contains(BiometricType.face)) return 'الوجه';
      if (list.contains(BiometricType.fingerprint)) return 'البصمة';
      if (list.contains(BiometricType.iris)) return 'القزحية';
      if (list.contains(BiometricType.strong) || list.contains(BiometricType.weak)) return 'القياس الحيوي';
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
          biometricOnly: false,   // allow PIN/pattern as a fallback
          stickyAuth: true,       // survive app backgrounding during the prompt
          useErrorDialogs: true,  // let the system render unenrolled / hardware-error UI
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'تأكيد الهوية',
            biometricHint: 'استخدم بصمتك أو وجهك',
            biometricNotRecognized: 'لم يتم التعرف عليك، حاول مجدداً',
            biometricSuccess: 'تم التحقق',
            cancelButton: 'إلغاء',
            deviceCredentialsRequiredTitle: 'القياس الحيوي غير مفعل',
            deviceCredentialsSetupDescription: 'يرجى إعداد بصمة أو رمز قفل في إعدادات الجهاز',
            goToSettingsButton: 'الإعدادات',
            goToSettingsDescription: 'يلزم إعداد القياس الحيوي للاستمرار',
          ),
          IOSAuthMessages(
            lockOut: 'تم قفل البصمة، أعد المحاولة لاحقاً',
            goToSettingsButton: 'الإعدادات',
            goToSettingsDescription: 'يلزم إعداد القياس الحيوي للاستمرار',
            cancelButton: 'إلغاء',
          ),
        ],
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
