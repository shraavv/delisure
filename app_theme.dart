import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors (gold accent system)
  static const Color primaryBlue = Color(0xFFD4A843);      // gold accent
  static const Color primaryBlueLight = Color(0xFFE8C660);  // accentLight
  static const Color primaryBlueDark = Color(0xFF8B7335);   // accentMuted

  // Accent
  static const Color accentAmber = Color(0xFFD4A843);       // gold
  static const Color accentAmberLight = Color(0xFFE8C660);  // gold light

  // Semantic
  static const Color successGreen = Color(0xFF22C55E);
  static const Color successGreenLight = Color(0xFF4ADE80);
  static const Color alertRed = Color(0xFFEF4444);
  static const Color alertRedLight = Color(0xFFF87171);
  static const Color warningOrange = Color(0xFFF59E0B);

  // Neutrals (dark theme)
  static const Color bgLight = Color(0xFF09090B);           // bgPrimary (near black)
  static const Color bgSecondary = Color(0xFF18181B);
  static const Color bgCard = Color(0xFF1C1C21);
  static const Color bgElevated = Color(0xFF232329);
  static const Color bgInput = Color(0xFF27272A);
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textHint = Color(0xFF52525B);
  static const Color dividerColor = Color(0xFF27272A);
  static const Color borderColor = Color(0xFF3F3F46);

  // Risk level colors
  static const Color riskLow = Color(0xFF22C55E);
  static const Color riskMedium = Color(0xFFF59E0B);
  static const Color riskHigh = Color(0xFFF97316);
  static const Color riskVeryHigh = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentAmber,
        surface: bgLight,
        error: alertRed,
        onPrimary: const Color(0xFF09090B),
        onSecondary: const Color(0xFF09090B),
        onSurface: textPrimary,
        onError: Colors.white,
        outline: borderColor,
      ),
      scaffoldBackgroundColor: bgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: bgSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF09090B),
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),
      // cardTheme: CardTheme(
      //   color: bgCard,
      //   elevation: 0,
      //   shadowColor: Colors.transparent,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(16),
      //     side: const BorderSide(color: borderColor, width: 0.5),
      //   ),
      //   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: const Color(0xFF09090B),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgElevated,
        selectedColor: primaryBlue.withAlpha(40),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: borderColor),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryBlue;
          }
          return textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryBlue.withAlpha(80);
          }
          return bgInput;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgSecondary,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textHint),
      ),
    );
  }

  static Color riskColor(double score) {
    if (score < 0.25) return riskLow;
    if (score < 0.5) return riskMedium;
    if (score < 0.75) return riskHigh;
    return riskVeryHigh;
  }

  static String riskLabel(double score) {
    if (score < 0.25) return 'Low';
    if (score < 0.5) return 'Medium';
    if (score < 0.75) return 'High';
    return 'Very High';
  }
}
