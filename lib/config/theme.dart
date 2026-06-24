import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SacoStay brand tokens — mirror web Tailwind config.
class SacoColors {
  SacoColors._();

  static const sacoOrange = Color(0xFFFF9F43);
  static const sacoOrangeDark = Color(0xFFFF8C2A);
  static const sacoBlue = Color(0xFF1A1A2E);
  static const sacoGray = Color(0xFF6B7280);
  static const pageBackground = Color(0xFFFFF8F0);
}

class SacoTheme {
  SacoTheme._();

  static ThemeData light() {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: SacoColors.pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SacoColors.sacoOrange,
        primary: SacoColors.sacoOrange,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: SacoColors.sacoBlue,
      ),
      textTheme: textTheme.apply(
        bodyColor: SacoColors.sacoGray,
        displayColor: SacoColors.sacoBlue,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        foregroundColor: SacoColors.sacoBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: SacoColors.sacoBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.orange.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.orange.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SacoColors.sacoOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        hintStyle: TextStyle(color: SacoColors.sacoGray.withValues(alpha: 0.7)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SacoColors.sacoOrange,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
