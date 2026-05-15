import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand palette derived from the app logo:
/// — deep navy background (#0F1729) like the logo's plate
/// — bright sky-blue (#3B82F6) like the "1" highlight and the Arabic text accent
/// — silver/white tones for text on dark
class AppColors {
  AppColors._();
  // Primary palette (logo-driven)
  static const Color primary      = Color(0xFF1E40AF); // royal blue — main brand
  static const Color primaryDark  = Color(0xFF0F1729); // logo background
  static const Color primaryDeep  = Color(0xFF172554); // between dark and primary
  static const Color primaryLight = Color(0xFF3B82F6); // logo accent
  static const Color primaryPale  = Color(0xFF60A5FA); // hover/active highlight
  static const Color secondary    = Color(0xFF06B6D4); // cyan — secondary accent
  static const Color accent       = Color(0xFFF59E0B); // amber — rewards/value
  static const Color accentLight  = Color(0xFFFBBF24);

  // Backgrounds
  static const Color bg           = Color(0xFFF8FAFC); // cool off-white
  static const Color bgTint       = Color(0xFFEFF6FF); // subtle blue wash for hero sections
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceAlt   = Color(0xFFF1F5F9); // slate-100
  static const Color card         = Color(0xFFFFFFFF);

  // Text
  static const Color text         = Color(0xFF0F172A);
  static const Color textSec      = Color(0xFF475569);
  static const Color textMuted    = Color(0xFF94A3B8);
  static const Color textOnPrimary= Color(0xFFFFFFFF);
  static const Color textOnDark   = Color(0xFFE2E8F0);

  // Status
  static const Color success      = Color(0xFF10B981);
  static const Color successBg    = Color(0xFFD1FAE5);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFEF4444);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoBg       = Color(0xFFDBEAFE);

  // Borders
  static const Color border       = Color(0xFFCBD5E1);
  static const Color borderLight  = Color(0xFFE2E8F0);
  static const Color divider      = Color(0xFFE2E8F0);

  // Category colors — modernized while keeping the previous semantics
  static const Color telecom      = Color(0xFF8B5CF6);
  static const Color electricity  = Color(0xFFF59E0B);
  static const Color gas          = Color(0xFFF97316);
  static const Color water        = Color(0xFF06B6D4);
  static const Color internet     = Color(0xFF10B981);
  static const Color insurance    = Color(0xFFA855F7);
  static const Color government   = Color(0xFF1E40AF);

  // B2B / Companies
  static const Color b2b          = Color(0xFF7C3AED);
  static const Color b2bBg        = Color(0xFFF5F3FF);

  // Subtle shadows
  static const Color shadowSoft   = Color(0x14000000);
  static const Color shadowFocus  = Color(0x33000000);
}

class AppGradients {
  AppGradients._();
  // Hero gradient (splash/login) — mirrors the logo's gradient from dark navy to bright blue.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF0F1729), Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF3B82F6)],
    stops: [0.0, 0.35, 0.75, 1.0],
  );
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
  );
  static const LinearGradient primaryDeep = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0F1729), Color(0xFF1E40AF)],
  );
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  );
  static const LinearGradient wallet = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0F1729), Color(0xFF1E40AF), Color(0xFF3B82F6)],
    stops: [0.0, 0.55, 1.0],
  );
  static const LinearGradient b2b = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
  );
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );
  static const LinearGradient cyan = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );
}

class D {
  D._();
  static const double xs = 4;  static const double sm = 8;
  static const double md = 16; static const double lg = 24;
  static const double xl = 32; static const double xxl = 48;
  static const double r4 = 4;  static const double r8 = 8;
  static const double r12= 12; static const double r16= 16;
  static const double r20= 20; static const double r24= 24;
  static const double btnH = 52; static const double cardR = 16;
}

class TS {
  TS._();
  static const _f = 'Cairo';
  static const TextStyle h1     = TextStyle(fontFamily:_f, fontSize:24, fontWeight:FontWeight.w700, color:AppColors.text, height:1.25);
  static const TextStyle h2     = TextStyle(fontFamily:_f, fontSize:20, fontWeight:FontWeight.w700, color:AppColors.text, height:1.3);
  static const TextStyle h3     = TextStyle(fontFamily:_f, fontSize:16, fontWeight:FontWeight.w600, color:AppColors.text, height:1.4);
  static const TextStyle body   = TextStyle(fontFamily:_f, fontSize:14, fontWeight:FontWeight.w400, color:AppColors.text, height:1.6);
  static const TextStyle bodyM  = TextStyle(fontFamily:_f, fontSize:14, fontWeight:FontWeight.w600, color:AppColors.text, height:1.5);
  static const TextStyle cap    = TextStyle(fontFamily:_f, fontSize:12, fontWeight:FontWeight.w400, color:AppColors.textSec, height:1.4);
  static const TextStyle capM   = TextStyle(fontFamily:_f, fontSize:12, fontWeight:FontWeight.w600, color:AppColors.textSec, height:1.3);
  static const TextStyle btn    = TextStyle(fontFamily:_f, fontSize:15, fontWeight:FontWeight.w700, color:Colors.white, height:1.2);
  static const TextStyle amount = TextStyle(fontFamily:_f, fontSize:28, fontWeight:FontWeight.w800, color:AppColors.text, height:1.1);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true, brightness: Brightness.light, fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary, onPrimary: Colors.white,
      primaryContainer: AppColors.infoBg, onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.secondary, onSecondary: Colors.white,
      tertiary: AppColors.accent, onTertiary: Colors.white,
      surface: AppColors.surface, onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceAlt,
      error: AppColors.error, outline: AppColors.border,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary, elevation: 0,
      centerTitle: true, scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: const TextStyle(fontFamily:'Cairo', fontSize:17, fontWeight:FontWeight.w700, color:Colors.white),
      iconTheme: const IconThemeData(color: Colors.white, size: 22),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? AppColors.divider : AppColors.primary),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) ? 1 : 2),
      shadowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.35)),
      minimumSize: WidgetStateProperty.all(const Size(double.infinity, D.btnH)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.r16))),
      textStyle: WidgetStateProperty.all(TS.btn),
      overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.08)),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all(AppColors.primary),
      side: WidgetStateProperty.all(const BorderSide(color: AppColors.primary, width: 1.5)),
      minimumSize: WidgetStateProperty.all(const Size(double.infinity, D.btnH)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.r16))),
      textStyle: WidgetStateProperty.all(TS.btn.copyWith(color: AppColors.primary)),
    )),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all(AppColors.primary),
      textStyle: WidgetStateProperty.all(TS.bodyM.copyWith(color: AppColors.primary)),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      labelStyle: TS.cap,
      hintStyle: TS.body.copyWith(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card, elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(D.cardR),
        side: const BorderSide(color: AppColors.borderLight, width: 1)),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface, selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed, elevation: 8,
      selectedLabelStyle: TextStyle(fontFamily:'Cairo', fontSize:11, fontWeight:FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily:'Cairo', fontSize:11),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryDark, contentTextStyle: TS.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 0),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt, selectedColor: AppColors.infoBg,
      labelStyle: TS.cap,
      side: const BorderSide(color: AppColors.borderLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
    ),
  );
}
