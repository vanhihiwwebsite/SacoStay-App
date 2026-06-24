import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'saco_footer.dart';
import 'saco_navbar.dart';

/// Overall app shell — navbar + scrollable body + optional footer.
class SacoScaffold extends StatelessWidget {
  const SacoScaffold({
    super.key,
    required this.body,
    this.showFooter = false,
    this.showNavbar = true,
  });

  final Widget body;
  final bool showFooter;
  final bool showNavbar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SacoColors.pageBackground,
      body: Column(
        children: [
          if (showNavbar) const SacoNavbar(),
          Expanded(
            child: body,
          ),
          if (showFooter) const SacoFooter(),
        ],
      ),
    );
  }
}
