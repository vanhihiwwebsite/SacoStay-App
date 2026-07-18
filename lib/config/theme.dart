import 'package:flutter/material.dart';

import '../core/design/design_system.dart';

/// SacoStay brand tokens — backward compatible alias for [AppColors].
class SacoColors {
  SacoColors._();

  static const sacoOrange = AppColors.primary;
  static const sacoOrangeDark = AppColors.primaryDark;
  static const sacoBlue = AppColors.secondary;
  static const sacoGray = AppColors.textSecondary;
  static const pageBackground = AppColors.background;
}

class SacoTheme {
  SacoTheme._();

  static ThemeData light() => AppTheme.light();
}
