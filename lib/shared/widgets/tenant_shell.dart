import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/design/design_system.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import 'saco_logo.dart';
import 'saco_notification_popup.dart';

/// Mobile shell for tenant/guest — bottom nav + compact top bar.
class TenantShell extends ConsumerWidget {
  const TenantShell({super.key, required this.body});

  final Widget body;

  static bool shouldUse(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 640) return false;
    final role = ref.watch(authControllerProvider).userRole;
    return role == 'tenant';
  }

  static void navigate(
    BuildContext context, {
    required String path,
    required bool isLoggedIn,
  }) {
    if (!isLoggedIn && _requiresAuth(path)) {
      context.go('/login?returnUrl=${Uri.encodeComponent(path)}');
      return;
    }
    if (GoRouterState.of(context).uri.path != path.split('?').first) {
      context.go(path);
    }
  }

  static bool _requiresAuth(String path) {
    final base = path.split('?').first;
    if (isTenantAuthPath(base)) return true;
    if (base == '/profile/me' || base.startsWith('/profile-setup')) return true;
    if (base.startsWith('/notifications')) return true;
    if (base.startsWith('/shared-space')) return true;
    return false;
  }

  static int bottomNavIndex(String path) {
    if (path == '/') return 0;
    if (path == '/rooms' || path.startsWith('/rooms/')) return 1;
    if (path == '/discovery') return 2;
    if (path == '/chat' || path.startsWith('/chat')) return 3;
    if (path.startsWith('/profile')) return 4;
    return -1;
  }

  /// Space to reserve above the bottom navigation bar (FAB + bar + safe area).
  static double bottomInset(BuildContext context) {
    const barHeight = 67.0;
    const fabOverhang = 20.0;
    return barHeight + fabOverhang + MediaQuery.paddingOf(context).bottom + 8;
  }

  /// Bottom offset for floating overlays (map stats bar, popups, …).
  static double bottomOverlayInset(BuildContext context) => bottomInset(context) + 12;

  /// Map stats bar sits just above the bottom nav labels.
  static double mapStatsBarBottom(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 8;
  }

  static bool shouldHideBottomNav(String path) {
    if (path == '/rooms') return false;
    return path.startsWith('/rooms/');
  }

  static const fabClearanceWidth = 68.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final hideBottomNav = shouldHideBottomNav(currentPath);
    final auth = ref.watch(authControllerProvider);
    final isLoggedIn = auth.isLoggedIn;
    final selected = bottomNavIndex(currentPath);
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final role = auth.userRole;
    final showPostListing = role != 'admin' &&
        (role == 'landlord' || (!isLoggedIn && currentPath == '/'));

    return Scaffold(
      extendBody: !hideBottomNav,
      backgroundColor: SacoColors.pageBackground,
      body: Column(
        children: [
          _TenantTopBar(
            unread: unread,
            isLoggedIn: isLoggedIn,
            showPostListing: showPostListing,
            onMap: () => context.go('/map'),
            onPostListing: () {
              if (!isLoggedIn) {
                context.go(
                  Uri(
                    path: '/login',
                    queryParameters: landlordPostListingQueryParams(),
                  ).toString(),
                );
                return;
              }
              context.go('/create-listing');
            },
            onPricing: () => context.go('/tenant-pricing'),
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
          : _TenantBottomBar(
              selectedIndex: selected,
              isLoggedIn: isLoggedIn,
              user: auth.user?.raw,
              onHome: () => navigate(context, path: '/', isLoggedIn: isLoggedIn),
              onRooms: () => navigate(context, path: '/rooms', isLoggedIn: isLoggedIn),
              onDiscovery: () => navigate(context, path: '/discovery', isLoggedIn: isLoggedIn),
              onChat: () => navigate(context, path: '/chat', isLoggedIn: isLoggedIn),
              onProfile: () => navigate(context, path: '/profile/me', isLoggedIn: isLoggedIn),
            ),
    );
  }
}

class _TenantTopBar extends StatelessWidget {
  const _TenantTopBar({
    required this.unread,
    required this.isLoggedIn,
    required this.showPostListing,
    required this.onMap,
    required this.onPostListing,
    required this.onPricing,
    required this.onNotifications,
  });

  final int unread;
  final bool isLoggedIn;
  final bool showPostListing;
  final VoidCallback onMap;
  final VoidCallback onPostListing;
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
                if (showPostListing)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Material(
                      color: SacoColors.sacoOrange,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: onPostListing,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Đăng tin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                _TopIconButton(
                  asset: BrandAssets.iconMap,
                  tooltip: 'Bản đồ',
                  onTap: onMap,
                ),
                _TopIconButton(
                  asset: BrandAssets.iconPricing,
                  tooltip: 'Bảng giá',
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

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
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

class _TenantBottomBar extends StatelessWidget {
  const _TenantBottomBar({
    required this.selectedIndex,
    required this.isLoggedIn,
    required this.user,
    required this.onHome,
    required this.onRooms,
    required this.onDiscovery,
    required this.onChat,
    required this.onProfile,
  });

  final int selectedIndex;
  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final VoidCallback onHome;
  final VoidCallback onRooms;
  final VoidCallback onDiscovery;
  final VoidCallback onChat;
  final VoidCallback onProfile;

  static const _activeColor = Color(0xFFE53935);
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
                      child: _NavItem(
                        label: 'Trang chủ',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        selected: selectedIndex == 0,
                        onTap: onHome,
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        label: 'Tìm phòng',
                        asset: BrandAssets.iconRooms,
                        selected: selectedIndex == 1,
                        onTap: onRooms,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: _NavItem(
                        label: 'Tin nhắn',
                        asset: BrandAssets.iconChat,
                        selected: selectedIndex == 3,
                        onTap: onChat,
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
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
                child: _DiscoveryFab(
                  selected: selectedIndex == 2,
                  onTap: onDiscovery,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    final color = selected ? _TenantBottomBar._activeColor : _TenantBottomBar._inactiveColor;

    Widget leading;
    if (avatarUrl != null && selected) {
      leading = CircleAvatar(
        radius: 13,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    } else if (asset != null) {
      leading = ColorFiltered(
        colorFilter: ColorFilter.mode(
          color,
          BlendMode.srcIn,
        ),
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

class _DiscoveryFab extends StatelessWidget {
  const _DiscoveryFab({
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
      color: selected ? const Color(0xFFE53935) : SacoColors.sacoOrange,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 59,
          height: 59,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                BrandAssets.iconDiscovery,
                width: 27,
                height: 27,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
              const SizedBox(height: 2),
              const Text(
                'Tìm bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
