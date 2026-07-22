import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../data/faq_data.dart';
import '../../shared/widgets/legal_mobile_widgets.dart';
import '../../shared/widgets/tenant_sub_page_scaffold.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String? _expandedId;

  IconData _iconFor(String id) => switch (id) {
        'pricing' => Icons.payments_outlined,
        'roommate-matching' => Icons.favorite_outline,
        'verified-listings' => Icons.verified_outlined,
        'contact-landlord' => Icons.chat_outlined,
        'roommate-support' => Icons.support_agent_outlined,
        _ => Icons.help_outline,
      };

  Color _colorFor(String id) => switch (id) {
        'pricing' => SacoColors.sacoOrange,
        'roommate-matching' => const Color(0xFFEC4899),
        'verified-listings' => const Color(0xFF10B981),
        'contact-landlord' => SacoColors.sacoBlue,
        'roommate-support' => const Color(0xFF8B5CF6),
        _ => SacoColors.sacoOrange,
      };

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            const LegalMobileHeader(
              badge: 'Hỗ trợ · SacoStay',
              title: 'Câu hỏi thường gặp',
              subtitle: 'Giải đáp nhanh các thắc mắc phổ biến khi dùng SacoStay.',
              icon: Icons.quiz_outlined,
            )
          else
            const LegalHero(
              badge: 'Hỗ trợ · SacoStay',
              title: 'Câu hỏi thường gặp (FAQ)',
              subtitle: 'Giải đáp nhanh các thắc mắc phổ biến và dẫn bạn đến trang thông tin chi tiết.',
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, isMobile ? 0 : 0, 16, 24),
            child: Column(
              children: [
                ...faqItems.map((item) {
                  final open = _expandedId == item.id;
                  final color = _colorFor(item.id);
                  return LegalInfoCard(
                    icon: _iconFor(item.id),
                    iconColor: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            _expandedId = open ? null : item.id;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.question,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: open
                                      ? color.withValues(alpha: 0.15)
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  open ? Icons.remove : Icons.add,
                                  size: 18,
                                  color: open ? color : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (open) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.shortAnswer,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.55,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => context.go('/faq/${item.id}'),
                              icon: Icon(Icons.arrow_forward, size: 16, color: color),
                              label: Text(
                                item.ctaLabel,
                                style: TextStyle(color: color, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/profile/me'),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Quay lại Cá nhân'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return TenantSubPageScaffold(
        title: 'FAQ',
        fallbackRoute: '/profile/me',
        body: content,
      );
    }
    return content;
  }
}

class FaqDetailScreen extends StatelessWidget {
  const FaqDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final item = faqById(id);
    if (item == null) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/faq'),
          child: const Text('Quay lại FAQ'),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LegalHero(
            badge: item.heroBadge,
            title: item.heroTitle,
            subtitle: item.heroSubtitle,
            footer: 'Trả lời bởi ${item.answeredBy}',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...item.sections.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (s.title != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  s.title!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ...s.paragraphs.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(p, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
                              ),
                            ),
                            if (s.list.isNotEmpty)
                              ...s.list.map(
                                (l) => Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• '),
                                      Expanded(child: Text(l)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )),
                  if (item.relatedLinks.isNotEmpty) ...[
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.relatedLinks
                          .map(
                            (l) => OutlinedButton(
                              onPressed: () => context.go(l.path),
                              child: Text(l.label),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => context.go('/faq'),
                        child: const Text('← FAQ'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Trang chủ'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalHero extends StatelessWidget {
  const LegalHero({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.footer,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SacoColors.sacoBlue,
            const Color(0xFF2d3748),
            SacoColors.sacoOrange.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(badge, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(footer!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
