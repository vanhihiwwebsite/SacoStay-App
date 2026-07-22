import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../providers/mobile_menu_provider.dart';
import 'saco_navbar.dart';

import 'tenant_shell.dart';
import 'landlord_shell.dart';

/// App shell: sticky navbar + scrollable body (footer lives inside page scroll).
class SacoScaffold extends ConsumerWidget {
  const SacoScaffold({
    super.key,
    required this.body,
    this.showNavbar = true,
  });

  final Widget body;
  final bool showNavbar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showNavbar) {
      return body;
    }

    if (TenantShell.shouldUse(context, ref)) {
      return TenantShell(body: body);
    }

    if (LandlordShell.shouldUse(context, ref)) {
      return LandlordShell(body: body);
    }

    final currentPath = GoRouterState.of(context).uri.path;
    final isDiscovery = currentPath == '/discovery';
    final discoveryMenuOpen =
        isDiscovery && ref.watch(discoveryMobileMenuOpenProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    if (currentPath != '/discovery' && ref.read(discoveryMobileMenuOpenProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(discoveryMobileMenuOpenProvider.notifier).state = false;
      });
    }

    return Scaffold(
      backgroundColor: SacoColors.pageBackground,
      body: Column(
        children: [
          if (showNavbar) const SacoNavbar(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                body,
                if (discoveryMenuOpen && isMobile)
                  DiscoveryMobileMenuOverlay(
                    onClose: () {
                      ref.read(discoveryMobileMenuOpenProvider.notifier).state = false;
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
