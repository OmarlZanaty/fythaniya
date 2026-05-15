import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  AppColors._();
  // Primary palette - Fawry-inspired teal/blue
  static const Color primary      = Color(0xFF0E7490); // main teal
  static const Color primaryDark  = Color(0xFF0C5F78);
  static const Color primaryLight = Color(0xFF22D3EE);
  static const Color accent       = Color(0xFFD97706); // gold accent
  static const Color accentLight  = Color(0xFFFBBF24);

  // Backgrounds
  static const Color bg           = Color(0xFFF0F9FF); // very light blue
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceAlt   = Color(0xFFE0F2FE);
  static const Color card         = Color(0xFFFFFFFF);

  // Text
  static const Color text         = Color(0xFF0F172A);
  static const Color textSec      = Color(0xFF475569);
  static const Color textMuted    = Color(0xFF94A3B8);
  static const Color textOnPrimary= Color(0xFFFFFFFF);

  // Status
  static const Color success      = Color(0xFF059669);
  static const Color successBg    = Color(0xFFD1FAE5);
  static const Color warning      = Color(0xFFD97706);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF0E7490);
  static const Color infoBg       = Color(0xFFE0F2FE);

  // Borders
  static const Color border       = Color(0xFFBAE6FD);
  static const Color divider      = Color(0xFFE2E8F0);

  // Category colors
  static const Color telecom      = Color(0xFF7C3AED);
  static const Color electricity  = Color(0xFFD97706);
  static const Color gas          = Color(0xFFEA580C);
  static const Color water        = Color(0xFF0EA5E9);
  static const Color internet     = Color(0xFF059669);
  static const Color insurance    = Color(0xFF7C3AED);
  static const Color government   = Color(0xFF0E7490);

  // B2B
  static const Color b2b          = Color(0xFF1D4ED8);
  static const Color b2bBg        = Color(0xFFEFF6FF);
}

class AppGradients {
  AppGradients._();
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0E7490), Color(0xFF0C5F78)],
  );
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
  );
  static const LinearGradient wallet = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0E7490), Color(0xFF164E63)],
  );
  static const LinearGradient b2b = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  );
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF047857)],
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
      secondary: AppColors.accent, onSecondary: Colors.white,
      surface: AppColors.surface, onSurface: AppColors.text,
      error: AppColors.error, outline: AppColors.border,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary, elevation: 0,
      centerTitle: true,
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
      elevation: WidgetStateProperty.all(0),
      minimumSize: WidgetStateProperty.all(const Size(double.infinity, D.btnH)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.r12))),
      textStyle: WidgetStateProperty.all(TS.btn),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all(AppColors.primary),
      side: WidgetStateProperty.all(const BorderSide(color: AppColors.primary, width: 1.5)),
      minimumSize: WidgetStateProperty.all(const Size(double.infinity, D.btnH)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.r12))),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(D.r12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      labelStyle: TS.cap,
      hintStyle: TS.body.copyWith(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card, elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(D.cardR),
        side: const BorderSide(color: AppColors.border, width: 0.8)),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface, selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed, elevation: 0,
      selectedLabelStyle: TextStyle(fontFamily:'Cairo', fontSize:11, fontWeight:FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily:'Cairo', fontSize:11),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text, contentTextStyle: TS.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      showDragHandle: true,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 0),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt, selectedColor: AppColors.infoBg,
      labelStyle: TS.cap, side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
