import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/widgets/saco_landlord_ui.dart';

class LandlordProfileScreen extends ConsumerWidget {
  const LandlordProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user?.raw;
    final name = navProfileLabel(user);
    final email = strField(user?['email'] ?? user?['Email']);
    final phone = strField(user?['phoneNumber'] ?? user?['PhoneNumber']);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SacoPageHeader(
            title: 'Hồ sơ Chủ trọ',
            subtitle: 'Thông tin tài khoản và quản lý tin đăng',
          ),
          SacoSectionCard(
            title: 'Thông tin cá nhân',
            child: Column(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage: NetworkImage(
                      resolveUserAvatarUrl(user, displayName: name),
                    ),
                    onBackgroundImageError: (_, __) {},
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Họ tên', value: name),
                _InfoRow(label: 'Email', value: email.isNotEmpty ? email : '—'),
                _InfoRow(label: 'SĐT', value: phone.isNotEmpty ? phone : '—'),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/profile-setup'),
                  child: const Text('Chỉnh sửa hồ sơ'),
                ),
              ],
            ),
          ),
          SacoSectionCard(
            title: 'Quản lý nhanh',
            child: Column(
              children: [
                _QuickLink(
                  icon: Icons.add_home_work_outlined,
                  label: 'Đăng tin mới',
                  onTap: () => context.go('/create-listing'),
                ),
                _QuickLink(
                  icon: Icons.view_list_outlined,
                  label: 'Tin đã đăng',
                  onTap: () => context.go('/my-listings'),
                ),
                _QuickLink(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Bảng giá VIP',
                  onTap: () => context.go('/landlord-pricing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: SacoColors.sacoOrange),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
