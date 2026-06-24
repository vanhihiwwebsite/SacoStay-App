import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';

class SacoFooter extends StatelessWidget {
  const SacoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.orange.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            BrandAssets.logoDark,
            height: 32,
            errorBuilder: (_, __, ___) => const Text(
              'SacoStay',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: SacoColors.sacoBlue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nền tảng tìm kiếm bạn ở ghép và phòng trọ thông minh dành cho giới trẻ Việt Nam.',
            style: TextStyle(color: SacoColors.sacoGray, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _FooterLink(label: 'Tìm bạn ở ghép', onTap: () => context.go('/discovery')),
              _FooterLink(label: 'Phòng trọ', onTap: () => context.go('/rooms')),
              _FooterLink(label: 'FAQ', onTap: () => context.go('/faq')),
              _FooterLink(label: 'Điều khoản', onTap: () => context.go('/terms')),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} SacoStay. Tìm bạn ở ghép hợp gu.',
            style: TextStyle(color: SacoColors.sacoGray.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: SacoColors.sacoGray,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: SacoColors.sacoOrange,
        ),
      ),
    );
  }
}
