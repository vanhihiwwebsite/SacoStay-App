import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';

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

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.go('/'),
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        BrandAssets.logoDark,
                        height: 36,
                        errorBuilder: (_, __, ___) => const Text(
                          'SacoStay',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: SacoColors.sacoBlue,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (MediaQuery.sizeOf(context).width >= 640)
                      ...visibleLinks.map(
                        (link) => _DesktopNavItem(
                          link: link,
                          isActive: currentPath == link.path,
                          isLoggedIn: isLoggedIn,
                          onTap: () => _navigateLink(context, link, isLoggedIn),
                        ),
                      ),
                    if (_showPostListingBtn(isLoggedIn, role, currentPath))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilledButton.icon(
                          onPressed: () => _onPostListing(context, isLoggedIn),
                          style: FilledButton.styleFrom(
                            backgroundColor: SacoColors.sacoOrange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Đăng tin'),
                        ),
                      ),
                    if (MediaQuery.sizeOf(context).width < 640)
                      IconButton(
                        onPressed: () => setState(() => _menuOpen = !_menuOpen),
                        icon: Icon(_menuOpen ? Icons.close : Icons.menu),
                        color: SacoColors.sacoGray,
                      )
                    else
                      _AuthActions(
                        isLoggedIn: isLoggedIn,
                        user: user,
                        onLogout: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                      ),
                  ],
                ),
              ),
              if (_menuOpen && MediaQuery.sizeOf(context).width < 640)
                _MobileMenu(
                  links: visibleLinks,
                  currentPath: currentPath,
                  isLoggedIn: isLoggedIn,
                  user: user,
                  showPostListing: _showPostListingBtn(isLoggedIn, role, currentPath),
                  onNavigate: (path) {
                    setState(() => _menuOpen = false);
                    context.go(path);
                  },
                  onNavLink: (link) {
                    setState(() => _menuOpen = false);
                    _navigateLink(context, link, isLoggedIn);
                  },
                  onPostListing: () {
                    setState(() => _menuOpen = false);
                    _onPostListing(context, isLoggedIn);
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

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.link,
    required this.isActive,
    required this.isLoggedIn,
    required this.onTap,
  });

  final NavLinkItem link;
  final bool isActive;
  final bool isLoggedIn;
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

class _AuthActions extends StatelessWidget {
  const _AuthActions({
    required this.isLoggedIn,
    required this.user,
    required this.onLogout,
  });

  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return Row(
        children: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Đăng nhập'),
          ),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('Đăng ký'),
          ),
        ],
      );
    }

    final label = navProfileLabel(user);
    final avatar = profileAvatarFromRaw(user);
    final avatarUrl = avatar != null ? resolveMediaUrl(avatar) : avatarFallbackUrl(label);

    return Row(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: Colors.orange.shade100,
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

class _MobileMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.orange.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...links.map((link) {
            final active = currentPath == link.path;
            return ListTile(
              leading: link.iconAsset != null
                  ? Image.asset(link.iconAsset!, width: 22, height: 22)
                  : const Icon(Icons.admin_panel_settings_outlined),
              title: Text(link.name),
              selected: active,
              selectedTileColor: SacoColors.pageBackground,
              onTap: () => onNavLink(link),
            );
          }),
          if (showPostListing)
            FilledButton.icon(
              onPressed: onPostListing,
              icon: const Icon(Icons.add),
              label: const Text('Đăng tin'),
              style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
            ),
          const SizedBox(height: 8),
          if (isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(navProfileLabel(user)),
              subtitle: Text(strField(user?['email'])),
              onTap: onLogout,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onNavigate('/login'),
                    child: const Text('Đăng nhập'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onNavigate('/register'),
                    child: const Text('Đăng ký'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
