import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // 🎨 BRAND COLORS
  // ---------------------------------------------------------------------------
  static const Color primaryOrange = Color(0xFFF19421);
  static const Color primaryRed = Color(0xFFB02029);
  static const Color backgroundLight = Color(0xFFF8F6F3);
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF212121);
  static const Color textGrey = Color(0xFF757575);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color shadowBlack = Colors.black;

  // ---------------------------------------------------------------------------
  // 🌈 GRADIENTS
  // ---------------------------------------------------------------------------

  /// Admin dashboard AppBar gradient
  static const LinearGradient titleGradient = LinearGradient(
    colors: [primaryOrange, primaryRed],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static Shader iconGradientShader(Rect bounds) {
  return const LinearGradient(
    colors: [primaryOrange, primaryRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(bounds);
}

  /// Homepage AppBar gradient
  static const LinearGradient homeAppBarGradient = LinearGradient(
    colors: [primaryOrange, primaryRed],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient categorySelectedGradient = LinearGradient(
    colors: [primaryOrange, primaryRed],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get imageOverlayGradient => LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 0.55),
          Colors.transparent,
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

  // ---------------------------------------------------------------------------
  // ✨ SHADOWS
  // ---------------------------------------------------------------------------
  static List<BoxShadow> get lightCardShadow => [
        BoxShadow(
          color: shadowBlack.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get bottomNavShadow => [
        BoxShadow(
          color: shadowBlack.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, -2),
        ),
      ];

  static List<BoxShadow> get selectedTabShadow => [
        BoxShadow(
          color: primaryRed.withValues(alpha: 0.35),
          blurRadius: 7,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get appBarShadow => [
        BoxShadow(
          color: shadowBlack.withValues(alpha: 0.12),
          blurRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  // ---------------------------------------------------------------------------
  // 🧱 RADIUS
  // ---------------------------------------------------------------------------
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius tabRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(12));

  // ---------------------------------------------------------------------------
  // 📏 SPACING SYSTEM
  // ---------------------------------------------------------------------------
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;

  // ---------------------------------------------------------------------------
  // 📝 TYPOGRAPHY
  // ---------------------------------------------------------------------------

  static TextStyle get titleText => GoogleFonts.hedvigLettersSerif(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get headingText => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get sectionTitle => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get cardTitleText => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get subtitleText => GoogleFonts.poppins(
        fontSize: 13,
        color: textGrey,
      );

  static TextStyle get smallLabel => GoogleFonts.poppins(
        fontSize: 11,
        color: textGrey,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get categoryTextSelected => GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get categoryTextUnselected => GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey,
        fontWeight: FontWeight.w500,
      );

  // ---------------------------------------------------------------------------
  // 🧭 GLOBAL THEME (100% ERROR-FREE)
  // ---------------------------------------------------------------------------
  static ThemeData get themeData {
    final defaultCardTheme = ThemeData().cardTheme;

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: backgroundLight,

      // ---------------- APP BAR ----------------
      appBarTheme: AppBarTheme(
  backgroundColor: Colors.transparent,   // <-- FIX
  elevation: 0,
  centerTitle: true,
  shadowColor: Colors.transparent,       // optional: prevent shadow blocking gradient
  surfaceTintColor: Colors.transparent,  // <-- FIX for Material 3
  titleTextStyle: titleText.copyWith(color: Colors.white),
),


      // ---------------- TEXT ----------------
      textTheme: TextTheme(
        headlineLarge: titleText,
        headlineMedium: headingText,
        titleMedium: sectionTitle,
        bodyLarge: subtitleText,
      ),

      // ---------------- CARD THEME (STABLE FIX) ----------------
      cardTheme: defaultCardTheme.copyWith(
        color: cardWhite,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shadowColor: shadowBlack.withValues(alpha: 0.08),
        shape: const RoundedRectangleBorder(
          borderRadius: cardRadius,
        ),
      ),

      // ---------------- INPUT FIELDS ----------------
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: buttonRadius,
          borderSide: const BorderSide(color: borderGrey),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: buttonRadius,
          borderSide: BorderSide(color: primaryRed, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
