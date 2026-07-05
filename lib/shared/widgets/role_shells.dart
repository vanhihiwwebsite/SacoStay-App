import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import 'saco_logo.dart';
import 'saco_notification_popup.dart';
import 'saco_scaffold.dart';

/// Landlord mobile shell — dark header + slide-out menu (mirror web responsive).
class LandlordShell extends ConsumerStatefulWidget {
  const LandlordShell({super.key, required this.body});

  final Widget body;

  @override
  ConsumerState<LandlordShell> createState() => _LandlordShellState();
}

class _LandlordShellState extends ConsumerState<LandlordShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _menuItems = [
    _LandlordNavItem('Hồ sơ Chủ trọ', Icons.person_outline, '/landlord-profile'),
    _LandlordNavItem('Đăng tin', Icons.edit_outlined, '/create-listing'),
    _LandlordNavItem('Tin đã đăng', Icons.view_list_outlined, '/my-listings'),
    _LandlordNavItem('Bảng giá', Icons.credit_card_outlined, '/landlord-pricing'),
    _LandlordNavItem('Tin nhắn', Icons.chat_bubble_outline, '/chat'),
    _LandlordNavItem('Lượt xem tin', Icons.visibility_outlined, '/listing-viewers'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: _LandlordDrawer(
        items: _menuItems,
        currentPath: currentPath,
        onNavigate: (path) {
          Navigator.of(context).pop();
          if (GoRouterState.of(context).uri.path != path) {
            context.go(path);
          }
        },
        onLogout: () {
          Navigator.of(context).pop();
          ref.read(authControllerProvider.notifier).logout();
        },
      ),
      body: Column(
        children: [
          _LandlordTopBar(
            vipLabel: 'PRO',
            unread: unread,
            onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
            onNotifications: () => showSacoNotificationPopup(context, ref),
            onHome: () => context.go('/'),
          ),
          Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: widget.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandlordTopBar extends StatelessWidget {
  const _LandlordTopBar({
    required this.vipLabel,
    required this.unread,
    required this.onMenu,
    required this.onNotifications,
    required this.onHome,
  });

  final String vipLabel;
  final int unread;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SacoColors.sacoBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SacoLogo(height: 36, light: true, onTap: onHome),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vipLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onNotifications,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_none, color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandlordDrawer extends ConsumerWidget {
  const _LandlordDrawer({
    required this.items,
    required this.currentPath,
    required this.onNavigate,
    required this.onLogout,
  });

  final List<_LandlordNavItem> items;
  final String currentPath;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  bool _isActive(_LandlordNavItem item) => currentPath == item.path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user?.raw;
    final name = navProfileLabel(user);
    final width = MediaQuery.sizeOf(context).width * 0.82;

    return Drawer(
      width: width,
      backgroundColor: SacoColors.sacoBlue,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            ...items.map((item) {
              final active = _isActive(item);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Material(
                  color: active ? SacoColors.sacoOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onNavigate(item.path),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(item.icon, color: Colors.white, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    backgroundImage: NetworkImage(
                      resolveUserAvatarUrl(user, displayName: name),
                    ),
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Chủ trọ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandlordNavItem {
  const _LandlordNavItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

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
    if (role == 'landlord') return LandlordShell(body: body);
    if (role == 'admin') return AdminShell(body: body);
    return SacoScaffold(body: body);
  }
}
