import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../data/faq_data.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LegalHero(
            badge: 'Hỗ trợ · SacoStay',
            title: 'Câu hỏi thường gặp (FAQ)',
            subtitle: 'Giải đáp nhanh các thắc mắc phổ biến và dẫn bạn đến trang thông tin chi tiết.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ...faqItems.map((item) {
                    final open = _expandedId == item.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() {
                              _expandedId = open ? null : item.id;
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.question,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: SacoColors.sacoBlue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    open ? '−' : '+',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: SacoColors.sacoOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (open)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.shortAnswer,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => context.go('/faq/${item.id}'),
                                    child: Text('${item.ctaLabel} →'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Về trang chủ'),
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
