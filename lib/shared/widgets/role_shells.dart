import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import 'saco_logo.dart';
import 'saco_scaffold.dart';

export 'landlord_shell.dart';

/// Admin mobile shell — light grey canvas + simple header (mirror web admin).
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          Material(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const SacoLogo(height: 36),
                    const Spacer(),
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: Icon(Icons.home_outlined, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Picks landlord / admin / tenant shell for shared routes (e.g. chat).
class SacoRouteShell extends ConsumerWidget {
  const SacoRouteShell({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).userRole;
    if (role == 'admin') return AdminShell(body: body);
    return SacoScaffold(body: body);
  }
}
