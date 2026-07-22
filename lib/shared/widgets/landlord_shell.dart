import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/design/design_system.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import 'saco_logo.dart';
import 'saco_notification_popup.dart';

/// Mobile shell for landlord — bottom nav + compact top bar (mirror tenant layout).
class LandlordShell extends ConsumerWidget {
  const LandlordShell({super.key, required this.body});

  final Widget body;

  static bool shouldUse(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 640) return false;
    final role = ref.watch(authControllerProvider).userRole;
    return role == 'landlord';
  }

  static void navigate(
    BuildContext context, {
    required String path,
    required bool isLoggedIn,
  }) {
    if (!isLoggedIn) {
      context.go('/login?returnUrl=${Uri.encodeComponent(path)}');
      return;
    }
    if (GoRouterState.of(context).uri.path != path.split('?').first) {
      context.go(path);
    }
  }

  static int bottomNavIndex(String path) {
    if (path == '/') return 0;
    if (path == '/my-listings' || path.startsWith('/my-listings/')) return 1;
    if (path == '/create-listing') return 2;
    if (path == '/chat' || path.startsWith('/chat')) return 3;
    if (path == '/profile/me' ||
        path.startsWith('/profile/me') ||
        path == '/landlord-profile') {
      return 4;
    }
    return -1;
  }

  static double bottomInset(BuildContext context) {
    const barHeight = 67.0;
    const fabOverhang = 20.0;
    return barHeight + fabOverhang + MediaQuery.paddingOf(context).bottom + 8;
  }

  /// Map stats bar sits just above the bottom nav labels.
  static double mapStatsBarBottom(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 8;
  }

  static bool shouldHideBottomNav(String path) {
    if (path == '/create-listing') return true;
    if (path == '/profile-setup') return true;
    if (path.startsWith('/profile/me/detail')) return true;
    if (path.startsWith('/rooms/')) return true;
    if (path.startsWith('/payment/')) return true;
    return false;
  }

  static bool shouldHideTopBar(String path) {
    return path == '/create-listing';
  }

  static const fabClearanceWidth = 68.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final hideBottomNav = shouldHideBottomNav(currentPath);
    final hideTopBar = shouldHideTopBar(currentPath);
    final auth = ref.watch(authControllerProvider);
    final isLoggedIn = auth.isLoggedIn;
    final selected = bottomNavIndex(currentPath);
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      extendBody: !hideBottomNav,
      backgroundColor: SacoColors.pageBackground,
      body: Column(
        children: [
          if (!hideTopBar)
            _LandlordTopBar(
              unread: unread,
              isLoggedIn: isLoggedIn,
              onMap: () => context.go('/map'),
              onPricing: () => context.go('/landlord-pricing'),
              onNotifications: () {
                if (!isLoggedIn) {
                  context.go('/login?returnUrl=${Uri.encodeComponent('/notifications')}');
                  return;
                }
                showSacoNotificationPopup(context, ref);
              },
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: hideBottomNav
          ? null
          : _LandlordBottomBar(
              selectedIndex: selected,
              isLoggedIn: isLoggedIn,
              user: auth.user?.raw,
              onHome: () => navigate(context, path: '/', isLoggedIn: isLoggedIn),
              onListings: () =>
                  navigate(context, path: '/my-listings', isLoggedIn: isLoggedIn),
              onCreateListing: () =>
                  navigate(context, path: '/create-listing', isLoggedIn: isLoggedIn),
              onChat: () => navigate(context, path: '/chat', isLoggedIn: isLoggedIn),
              onProfile: () =>
                  navigate(context, path: '/profile/me', isLoggedIn: isLoggedIn),
            ),
    );
  }
}

class _LandlordTopBar extends StatelessWidget {
  const _LandlordTopBar({
    required this.unread,
    required this.isLoggedIn,
    required this.onMap,
    required this.onPricing,
    required this.onNotifications,
  });

  final int unread;
  final bool isLoggedIn;
  final VoidCallback onMap;
  final VoidCallback onPricing;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.98),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          boxShadow: AppShadows.sm,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                SacoLogo(height: 38, onTap: () => context.go('/')),
                const Spacer(),
                _LandlordTopIconButton(
                  asset: BrandAssets.iconMap,
                  tooltip: 'Bản đồ',
                  onTap: onMap,
                ),
                _LandlordTopIconButton(
                  asset: BrandAssets.iconPricing,
                  tooltip: 'Bảng giá VIP',
                  onTap: onPricing,
                ),
                IconButton(
                  onPressed: onNotifications,
                  tooltip: 'Thông báo',
                  icon: Badge(
                    isLabelVisible: isLoggedIn && unread > 0,
                    label: Text('$unread'),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandlordTopIconButton extends StatelessWidget {
  const _LandlordTopIconButton({
    required this.asset,
    required this.tooltip,
    required this.onTap,
  });

  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Image.asset(asset, width: 23, height: 23),
    );
  }
}

class _LandlordBottomBar extends StatelessWidget {
  const _LandlordBottomBar({
    required this.selectedIndex,
    required this.isLoggedIn,
    required this.user,
    required this.onHome,
    required this.onListings,
    required this.onCreateListing,
    required this.onChat,
    required this.onProfile,
  });

  final int selectedIndex;
  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final VoidCallback onHome;
  final VoidCallback onListings;
  final VoidCallback onCreateListing;
  final VoidCallback onChat;
  final VoidCallback onProfile;

  static const _activeColor = Color(0xFF1E3A8A);
  static const _inactiveColor = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 67,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: _LandlordNavItem(
                        label: 'Trang chủ',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        selected: selectedIndex == 0,
                        onTap: onHome,
                      ),
                    ),
                    Expanded(
                      child: _LandlordNavItem(
                        label: 'Tin đã đăng',
                        icon: Icons.view_list_outlined,
                        activeIcon: Icons.view_list,
                        selected: selectedIndex == 1,
                        onTap: onListings,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: _LandlordNavItem(
                        label: 'Tin nhắn',
                        asset: BrandAssets.iconChat,
                        selected: selectedIndex == 3,
                        onTap: onChat,
                      ),
                    ),
                    Expanded(
                      child: _LandlordNavItem(
                        label: 'Cá nhân',
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        selected: selectedIndex == 4,
                        onTap: onProfile,
                        avatarUrl: isLoggedIn
                            ? resolveUserAvatarUrl(
                                user,
                                displayName: navProfileLabel(user),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -19,
                child: _CreateListingFab(
                  selected: selectedIndex == 2,
                  onTap: onCreateListing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandlordNavItem extends StatelessWidget {
  const _LandlordNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.activeIcon,
    this.asset,
    this.avatarUrl,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? activeIcon;
  final String? asset;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? _LandlordBottomBar._activeColor : _LandlordBottomBar._inactiveColor;

    Widget leading;
    if (avatarUrl != null && selected) {
      leading = CircleAvatar(
        radius: 13,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    } else if (asset != null) {
      leading = ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Image.asset(asset!, width: 23, height: 23),
      );
    } else {
      leading = Icon(
        selected ? (activeIcon ?? icon) : icon,
        size: 23,
        color: color,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateListingFab extends StatelessWidget {
  const _CreateListingFab({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: selected ? 8 : 6,
      shape: const CircleBorder(),
      color: selected ? SacoColors.sacoOrangeDark : SacoColors.sacoOrange,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 59,
          height: 59,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_home_work_outlined, color: Colors.white, size: 26),
              const SizedBox(height: 2),
              Text(
                'Đăng tin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
