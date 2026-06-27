import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'saco_navbar.dart';

/// App shell: sticky navbar + scrollable body (footer lives inside page scroll).
class SacoScaffold extends StatelessWidget {
  const SacoScaffold({
    super.key,
    required this.body,
    this.showNavbar = true,
  });

  final Widget body;
  final bool showNavbar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SacoColors.pageBackground,
      body: Column(
        children: [
          if (showNavbar) const SacoNavbar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
