import 'package:flutter/material.dart';

/// Brand + semantic colors for SacoStay.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFFFF9F43);
  static const primaryDark = Color(0xFFFF8C2A);
  static const primaryLight = Color(0xFFFFEDD5);
  static const secondary = Color(0xFF1A1A2E);

  // Text
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const textOnPrimary = Colors.white;

  // Surfaces
  static const background = Color(0xFFFFF8F0);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF9FAFB);

  // Borders
  static const border = Color(0xFFF3F4F6);
  static const borderAccent = Color(0xFFFFEDD5);

  // Semantic
  static const success = Color(0xFF10B981);
  static const successMuted = Color(0xFFD1FAE5);
  static const error = Color(0xFFEF4444);
  static const errorMuted = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF59E0B);
  static const warningMuted = Color(0xFFFEF3C7);
  static const info = Color(0xFF3B82F6);
  static const infoMuted = Color(0xFFDBEAFE);
}
