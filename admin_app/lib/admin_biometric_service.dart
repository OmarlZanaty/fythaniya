import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin-side biometric wrapper. Same API as the user app's BiometricService,
/// but stores its "enabled" flag under a separate key.
class AdminBiometricService {
  AdminBiometricService._();
  static final AdminBiometricService instance = AdminBiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const _enabledKey = 'fyt_admin_biometric_enabled';

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

  Future<String> bestAvailableLabel() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      if (list.contains(BiometricType.face)) return 'الوجه';
      if (list.contains(BiometricType.fingerprint)) return 'البصمة';
      if (list.contains(BiometricType.iris)) return 'القزحية';
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

  Future<bool> authenticate({String reason = 'تأكيد هويتك للدخول إلى لوحة الإدارة'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
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
      debugPrint('[AdminBiometric] authenticate failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AdminBiometric] authenticate unexpected: $e');
      return false;
    }
  }
}
