import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/brand_social.dart';
import '../../config/theme.dart';
import 'saco_logo.dart';

class SacoFooter extends StatelessWidget {
  const SacoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.orange.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SacoLogo(height: 48),
          const SizedBox(height: 12),
          const Text(
            'Nền tảng tìm kiếm bạn ở ghép và phòng trọ thông minh dành cho giới trẻ Việt Nam.',
            style: TextStyle(color: SacoColors.sacoGray, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SocialIcon(
                icon: Icons.facebook,
                onTap: () => _openUrl(BrandSocial.facebookUrl),
              ),
              const SizedBox(width: 16),
              _SocialIcon(
                icon: Icons.music_note_outlined,
                onTap: () => _openUrl(BrandSocial.tiktokUrl),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _FooterColumn(
            title: 'KHÁM PHÁ',
            links: [
              _FooterLinkItem('Tìm bạn ở ghép', () => context.go('/discovery')),
              _FooterLinkItem('Tìm phòng trọ', () => context.go('/rooms')),
              _FooterLinkItem('Trắc nghiệm lối sống', () => context.go('/lifestyle-quiz')),
            ],
          ),
          const SizedBox(height: 20),
          _FooterColumn(
            title: 'HỖ TRỢ',
            links: [
              _FooterLinkItem('Điều khoản & Chính sách', () => context.go('/terms')),
              _FooterLinkItem('Câu hỏi thường gặp (FAQ)', () => context.go('/faq')),
            ],
          ),
          const SizedBox(height: 20),
          _FooterColumn(
            title: 'LIÊN HỆ',
            links: [
              _FooterLinkItem('Email: sacostay79@gmail.com', null),
              _FooterLinkItem('Hotline: 0366723474', null),
              _FooterLinkItem(
                'Địa chỉ: Đại học FPT Hồ Chí Minh, Khu Công nghệ cao',
                null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.orange.shade100),
          const SizedBox(height: 16),
          Text(
            '© ${DateTime.now().year} SacoStay. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SacoColors.sacoGray.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLinkItem> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SacoColors.sacoBlue,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: link.onTap,
              child: Text(
                link.label,
                style: const TextStyle(color: SacoColors.sacoGray, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLinkItem {
  const _FooterLinkItem(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: SacoColors.sacoGray.withValues(alpha: 0.6)),
      ),
    );
  }
}
