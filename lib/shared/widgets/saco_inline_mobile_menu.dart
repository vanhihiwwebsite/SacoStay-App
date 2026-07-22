import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/user_display.dart';
import '../../repositories/notification_repository.dart';
import 'saco_mobile_menu.dart';
import 'saco_notification_popup.dart';

class SacoInlineMobileMenu extends ConsumerWidget {
  const SacoInlineMobileMenu({
    super.key,
    required this.links,
    required this.currentPath,
    required this.isLoggedIn,
    required this.user,
    required this.role,
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
  final String role;
  final bool showPostListing;
  final void Function(String path) onNavigate;
  final void Function(NavLinkItem link) onNavLink;
  final VoidCallback onPostListing;
  final VoidCallback onLogout;

  void _openNotifications(BuildContext context, WidgetRef ref) {
    showSacoNotificationPopup(context, ref);
  }

  String get _profilePath => '/profile/me';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final label = navProfileLabel(user);
    final avatarUrl = resolveUserAvatarUrl(user, displayName: label);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.orange.shade100),
          bottom: BorderSide(color: Colors.orange.shade100),
        ),
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
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: _PostListingButton(onPressed: onPostListing),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: Colors.orange.shade100),
          const SizedBox(height: 8),
          if (isLoggedIn)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => onNavigate(_profilePath),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread'),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_outlined, size: 22),
                          onPressed: () => _openNotifications(context, ref),
                        ),
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

class _PostListingButton extends StatelessWidget {
  const _PostListingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SacoColors.sacoOrange, SacoColors.sacoOrangeDark],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Đăng tin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
