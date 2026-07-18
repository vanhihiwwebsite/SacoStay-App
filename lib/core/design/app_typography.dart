import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Inter typography — 5 sizes: 13, 16, 18, 22, 28.
abstract final class AppTypography {
  static const double caption = 13;
  static const double body = 16;
  static const double title = 18;
  static const double headline = 22;
  static const double display = 28;

  static TextTheme textTheme([TextTheme? base]) {
    final inter = GoogleFonts.interTextTheme(base);
    return inter.copyWith(
      displayMedium: inter.displayMedium?.copyWith(
        fontSize: display,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),
      headlineSmall: inter.headlineSmall?.copyWith(
        fontSize: headline,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontSize: title,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontSize: caption,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: body,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontSize: caption,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontSize: caption,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      ),
    );
  }

  static TextStyle get displayStyle => TextStyle(
        fontSize: display,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineStyle => TextStyle(
        fontSize: headline,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleStyle => TextStyle(
        fontSize: title,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyStyle => TextStyle(
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get captionStyle => TextStyle(
        fontSize: caption,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelStyle => TextStyle(
        fontSize: caption,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: AppColors.textPrimary,
      );
}
