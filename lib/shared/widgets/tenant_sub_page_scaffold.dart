import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

/// Full-screen sub-page for tenant mobile (no bottom nav) with back header.
class TenantSubPageScaffold extends StatelessWidget {
  const TenantSubPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.fallbackRoute = '/profile/me',
  });

  final String title;
  final Widget body;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SacoColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallbackRoute);
            }
          },
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}
