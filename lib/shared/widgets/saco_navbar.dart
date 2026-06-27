import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/notification_repository.dart';
import 'saco_logo.dart';

class NavLinkItem {
  const NavLinkItem({
    required this.name,
    required this.path,
    required this.roles,
    this.iconAsset,
  });

  final String name;
  final String path;
  final List<String> roles;
  final String? iconAsset;
}

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
                        onProfile: () => context.go('/profile/me'),
                        onLogout: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                      ),
                    ] else ...[
                      if (showPostBtn) ...[
                        _PostListingButton(
                          compact: true,
                          onPressed: () => _onPostListing(context, isLoggedIn),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        onPressed: () => setState(() => _menuOpen = !_menuOpen),
                        icon: Icon(
                          _menuOpen ? Icons.close : Icons.menu,
                          color: SacoColors.sacoGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_menuOpen && isMobile)
                _MobileMenu(
                  links: visibleLinks,
                  currentPath: currentPath,
                  isLoggedIn: isLoggedIn,
                  user: user,
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
    context.go('/landlord-profile');
  }

  void _navigateLink(BuildContext context, NavLinkItem link, bool isLoggedIn) {
    if (!isLoggedIn && isTenantAuthPath(link.path)) {
      context.go('/login?returnUrl=${Uri.encodeComponent(link.path)}');
      return;
    }
    context.go(link.path);
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
    required this.onProfile,
    required this.onLogout,
  });

  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

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
          onPressed: () {},
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

class _MobileMenu extends ConsumerWidget {
  const _MobileMenu({
    required this.links,
    required this.currentPath,
    required this.isLoggedIn,
    required this.user,
    required this.showPostListing,
    required this.onNavigate,
    required this.onNavLink,
    required this.onPostListing,
    required this.onLogout,
  });

  final List<NavLinkItem> links;
  final String currentPath;
  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final bool showPostListing;
  final void Function(String path) onNavigate;
  final void Function(NavLinkItem link) onNavLink;
  final VoidCallback onPostListing;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final label = navProfileLabel(user);
    final avatarUrl = resolveUserAvatarUrl(user, displayName: label);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.orange.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...links.map((link) {
            final active = currentPath == link.path;
            return Material(
              color: active ? SacoColors.pageBackground : Colors.white,
              child: InkWell(
                onTap: () => onNavLink(link),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      if (link.iconAsset != null)
                        Image.asset(link.iconAsset!, width: 22, height: 22),
                      if (link.iconAsset != null) const SizedBox(width: 12),
                      Text(
                        link.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: active ? SacoColors.sacoOrange : SacoColors.sacoGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (showPostListing) ...[
            const SizedBox(height: 8),
            _PostListingButton(compact: false, onPressed: onPostListing),
          ],
          const SizedBox(height: 12),
          Divider(color: Colors.orange.shade100),
          const SizedBox(height: 8),
          if (isLoggedIn)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => onNavigate('/profile/me'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread'),
                        child: const Icon(Icons.notifications_outlined, size: 22),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(avatarUrl),
                        backgroundColor: Colors.orange.shade100,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              strField(user?['email']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: onLogout,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                _MobileAuthButton(
                  label: 'Đăng nhập',
                  iconAsset: BrandAssets.iconLogin,
                  onTap: () => onNavigate('/login'),
                ),
                const SizedBox(height: 10),
                _MobileAuthButton(
                  label: 'Đăng ký',
                  iconAsset: BrandAssets.iconRegister,
                  onTap: () => onNavigate('/register'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MobileAuthButton extends StatelessWidget {
  const _MobileAuthButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: SacoColors.sacoBlue,
        side: BorderSide(color: Colors.orange.shade100),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconAsset, width: 16, height: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
