import 'package:flutter/material.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';

class SacoLogo extends StatelessWidget {
  const SacoLogo({
    super.key,
    this.height = 40,
    this.onTap,
    this.light = false,
  });

  final double height;
  final VoidCallback? onTap;
  /// White logo/text for dark backgrounds (landlord header, drawer).
  final bool light;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      light ? BrandAssets.logoWhite : BrandAssets.logoDark,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        'SacoStay',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: height * 0.55,
          color: light ? Colors.white : SacoColors.sacoBlue,
        ),
      ),
    );

    if (onTap == null) return image;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }
}
