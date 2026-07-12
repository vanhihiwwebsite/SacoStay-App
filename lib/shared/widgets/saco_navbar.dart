import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import 'saco_logo.dart';
import '../providers/mobile_menu_provider.dart';
import 'saco_inline_mobile_menu.dart';
import 'saco_mobile_menu.dart';
import 'saco_notification_popup.dart';

class SacoNavbar extends ConsumerStatefulWidget {
  const SacoNavbar({super.key});

  @override
  ConsumerState<SacoNavbar> createState() => _SacoNavbarState();
}

class _SacoNavbarState extends ConsumerState<SacoNavbar> {
  bool _menuOpen = false;

  static const _links = [
    NavLinkItem(
      name: 'Tìm bạn',
      path: '/discovery',
      roles: ['tenant'],
      iconAsset: BrandAssets.iconDiscovery,
    ),
    NavLinkItem(
      name: 'Phòng trọ',
      path: '/rooms',
      roles: ['tenant', 'landlord'],
      iconAsset: BrandAssets.iconRooms,
    ),
    NavLinkItem(
      name: 'Bản đồ',
      path: '/map',
      roles: ['tenant', 'landlord'],
      iconAsset: BrandAssets.iconMap,
    ),
    NavLinkItem(
      name: 'Tin nhắn',
      path: '/chat',
      roles: ['tenant'],
      iconAsset: BrandAssets.iconChat,
    ),
    NavLinkItem(
      name: 'Bảng giá',
      path: '/tenant-pricing',
      roles: ['tenant'],
      iconAsset: BrandAssets.iconPricing,
    ),
    NavLinkItem(
      name: 'Tin của tôi',
      path: '/my-listings',
      roles: ['landlord'],
      iconAsset: BrandAssets.iconRooms,
    ),
    NavLinkItem(name: 'Quản trị', path: '/admin', roles: ['admin']),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.userRole;
    final isLoggedIn = auth.isLoggedIn;
    final user = auth.user?.raw;
    final visibleLinks = _links.where((l) => l.roles.contains(role)).toList();
    final currentPath = GoRouterState.of(context).uri.path;
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final isDiscovery = currentPath == '/discovery';
    final discoveryMenuOpen = ref.watch(discoveryMobileMenuOpenProvider);
    final showPostBtn = _showPostListingBtn(isLoggedIn, role, currentPath);

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.orange.shade100)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    SacoLogo(
                      height: isMobile ? 40 : 48,
                      onTap: () => context.go('/'),
                    ),
                    const Spacer(),
                    if (!isMobile) ...[
                      ...visibleLinks.map(
                        (link) => _DesktopNavItem(
                          link: link,
                          isActive: currentPath == link.path,
                          onTap: () => _navigateLink(context, link, isLoggedIn),
                        ),
                      ),
                      if (showPostBtn) ...[
                        const SizedBox(width: 8),
                        _PostListingButton(
                          compact: false,
                          onPressed: () => _onPostListing(context, isLoggedIn),
                        ),
                      ],
                      _AuthActions(
                        isLoggedIn: isLoggedIn,
                        user: user,
                        role: role,
                        onProfile: () {
                          if (role == 'landlord') {
                            context.go('/landlord-profile');
                          } else {
                            context.go('/profile/me');
                          }
                        },
                        onLogout: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                      ),
                    ] else ...[
                      IconButton(
                        onPressed: () {
                          if (isDiscovery) {
                            ref
                                .read(discoveryMobileMenuOpenProvider.notifier)
                                .update((open) => !open);
                          } else {
                            setState(() => _menuOpen = !_menuOpen);
                          }
                        },
                        icon: Icon(
                          isDiscovery
                              ? (discoveryMenuOpen ? Icons.close : Icons.menu)
                              : (_menuOpen ? Icons.close : Icons.menu),
                          color: SacoColors.sacoGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_menuOpen && isMobile && !isDiscovery)
                SacoInlineMobileMenu(
                  links: visibleLinks,
                  currentPath: currentPath,
                  isLoggedIn: isLoggedIn,
                  user: user,
                  role: role,
                  showPostListing: showPostBtn,
                  onNavLink: (link) {
                    setState(() => _menuOpen = false);
                    _navigateLink(context, link, isLoggedIn);
                  },
                  onPostListing: () {
                    setState(() => _menuOpen = false);
                    _onPostListing(context, isLoggedIn);
                  },
                  onNavigate: (path) {
                    setState(() => _menuOpen = false);
                    context.go(path);
                  },
                  onLogout: () {
                    setState(() => _menuOpen = false);
                    ref.read(authControllerProvider.notifier).logout();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _showPostListingBtn(bool isLoggedIn, String role, String path) {
    if (role == 'admin') return false;
    if (isLoggedIn && role == 'tenant') return false;
    if (!isLoggedIn) return path == '/';
    return role == 'landlord';
  }

  void _onPostListing(BuildContext context, bool isLoggedIn) {
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
  }

  void _navigateLink(BuildContext context, NavLinkItem link, bool isLoggedIn) {
    if (!isLoggedIn && isTenantAuthPath(link.path)) {
      context.go('/login?returnUrl=${Uri.encodeComponent(link.path)}');
      return;
    }
    context.go(link.path);
  }
}

/// Discovery menu overlay: push-down panel over page content without resizing body.
class DiscoveryMobileMenuOverlay extends ConsumerWidget {
  const DiscoveryMobileMenuOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  static const _links = [
    NavLinkItem(
      name: 'Tìm bạn',
      path: '/discovery',
      roles: ['tenant'],
      iconAsset: BrandAssets.iconDiscovery,
    ),
    NavLinkItem(
      name: 'Phòng trọ',
      path: '/rooms',
      roles: ['tenant', 'landlord'],
      iconAsset: BrandAssets.iconRooms,
    ),
    NavLinkItem(
      name: 'Bản đồ',
      path: '/map',
      roles: ['tenant', 'landlord'],
      iconAsset: BrandAssets.iconMap,
    ),
    NavLinkItem(
      name: 'Tin nhắn',
      path: '/chat',
      roles: ['tenant'],
      iconAsset: BrandAssets.iconChat,
    ),
    NavLinkItem(
      name: 'Bảng giá',
      path: '/tenant-pricing',
      roles: ['tenant'],
      iconAsset: BrandAssets.iconPricing,
    ),
    NavLinkItem(
      name: 'Tin của tôi',
      path: '/my-listings',
      roles: ['landlord'],
      iconAsset: BrandAssets.iconRooms,
    ),
    NavLinkItem(name: 'Quản trị', path: '/admin', roles: ['admin']),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.userRole;
    final isLoggedIn = auth.isLoggedIn;
    final user = auth.user?.raw;
    final currentPath = GoRouterState.of(context).uri.path;
    final visibleLinks = _links.where((l) => l.roles.contains(role)).toList();
    final showPostBtn = _showPostListingBtn(isLoggedIn, role, currentPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacoInlineMobileMenu(
          links: visibleLinks,
          currentPath: currentPath,
          isLoggedIn: isLoggedIn,
          user: user,
          role: role,
          showPostListing: showPostBtn,
          onNavLink: (link) {
            onClose();
            if (!isLoggedIn && isTenantAuthPath(link.path)) {
              context.go('/login?returnUrl=${Uri.encodeComponent(link.path)}');
              return;
            }
            context.go(link.path);
          },
          onPostListing: () {
            onClose();
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
          onNavigate: (path) {
            onClose();
            context.go(path);
          },
          onLogout: () {
            onClose();
            ref.read(authControllerProvider.notifier).logout();
          },
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }

  bool _showPostListingBtn(bool isLoggedIn, String role, String path) {
    if (role == 'admin') return false;
    if (isLoggedIn && role == 'tenant') return false;
    if (!isLoggedIn) return path == '/';
    return role == 'landlord';
  }
}

class _PostListingButton extends StatelessWidget {
  const _PostListingButton({
    required this.onPressed,
    required this.compact,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SacoColors.sacoOrange, SacoColors.sacoOrangeDark],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: SacoColors.sacoOrange.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20,
              vertical: compact ? 8 : 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Đăng tin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
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

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.link,
    required this.isActive,
    required this.onTap,
  });

  final NavLinkItem link;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(
                  bottom: BorderSide(color: SacoColors.sacoOrange, width: 2),
                )
              : null,
        ),
        child: Row(
          children: [
            if (link.iconAsset != null)
              Image.asset(link.iconAsset!, width: 16, height: 16),
            if (link.iconAsset != null) const SizedBox(width: 6),
            Text(
              link.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? SacoColors.sacoBlue : SacoColors.sacoGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthActions extends ConsumerWidget {
  const _AuthActions({
    required this.isLoggedIn,
    required this.user,
    required this.role,
    required this.onProfile,
    required this.onLogout,
  });

  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final String role;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  void _openNotifications(BuildContext context, WidgetRef ref) {
    final box = context.findRenderObject() as RenderBox?;
    final offset = box?.localToGlobal(Offset.zero);
    showSacoNotificationPopup(
      context,
      ref,
      anchorOffset: offset != null ? Offset(offset.dx, offset.dy + box!.size.height) : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLoggedIn) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: Image.asset(BrandAssets.iconLogin, width: 16, height: 16),
            label: const Text('Đăng nhập'),
          ),
          TextButton.icon(
            onPressed: () => context.go('/register'),
            icon: Image.asset(BrandAssets.iconRegister, width: 16, height: 16),
            label: const Text('Đăng ký'),
          ),
        ],
      );
    }

    final label = navProfileLabel(user);
    final avatarUrl = resolveUserAvatarUrl(user, displayName: label);
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unread = unreadAsync.value ?? 0;

    return Row(
      children: [
        IconButton(
          onPressed: () => _openNotifications(context, ref),
          tooltip: 'Thông báo',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor: Colors.orange.shade100,
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: SacoColors.sacoBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          tooltip: 'Đăng xuất',
          color: SacoColors.sacoGray,
        ),
      ],
    );
  }
}
