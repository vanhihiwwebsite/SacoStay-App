import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft, subtle elevation shadows.
abstract final class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> primaryGlow({double opacity = 0.28}) => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
