import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_assets.dart';
import '../../config/theme.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/widgets/saco_scaffold.dart';
import 'home_faq_data.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _expandedFaqId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoggedIn && isAdminUser(auth.user?.raw)) {
        context.go('/admin');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoggedIn = auth.isLoggedIn;
    final landlordCtaLink = isLoggedIn ? '/landlord-profile' : '/login';
    final landlordQuery = isLoggedIn ? null : landlordPostListingQueryParams();

    return SacoScaffold(
      showFooter: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroBanner(),
            _HeroIntro(),
            _FeatureSection(),
            _HowItWorksSection(onSearch: () => context.go('/rooms')),
            _CommunitySection(onDiscover: () => context.go('/discovery')),
            _LandlordSection(
              landlordLink: landlordCtaLink,
              landlordQuery: landlordQuery,
            ),
            _TrustSection(),
            _FaqSection(
              expandedId: _expandedFaqId,
              onToggle: (id) => setState(() {
                _expandedFaqId = _expandedFaqId == id ? null : id;
              }),
            ),
            _FinalCtaSection(
              landlordLink: landlordCtaLink,
              landlordQuery: landlordQuery,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: Image.asset(
        BrandAssets.heroBackground,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => Container(
          color: SacoColors.sacoOrange.withValues(alpha: 0.15),
          alignment: Alignment.center,
          child: const Text(
            'SacoStay',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: SacoColors.sacoBlue,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: const Text(
        'Cộng đồng sinh viên giúp bạn tìm phòng trọ đáng tin cậy và roommate phù hợp cho hành trình đại học.',
        textAlign: TextAlign.center,
        style: TextStyle(color: SacoColors.sacoGray, fontSize: 15, height: 1.5),
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: Colors.white,
      title: 'Vì sao chọn SacoStay?',
      subtitle: 'Nền tảng dành riêng cho sinh viên — minh bạch, an toàn và dễ bắt đầu.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final crossCount = w >= 900 ? 4 : (w >= 500 ? 2 : 1);
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossCount == 1 ? 1.6 : 1.1,
            children: const [
              _FeatureCard(
                emoji: '🏠',
                title: 'Tin đăng đã kiểm duyệt',
                body:
                    'Tin đăng được kiểm duyệt trước khi xuất hiện trên nền tảng nhằm hạn chế thông tin sai lệch.',
              ),
              _FeatureCard(
                emoji: '👤',
                title: 'Chủ trọ đã xác minh',
                body: 'Chủ trọ được xác minh thông tin nhằm tăng độ tin cậy và minh bạch.',
              ),
              _FeatureCard(
                emoji: '🤝',
                title: 'Ghép roommate thông minh',
                body: 'Tìm roommate phù hợp dựa trên nhu cầu, sở thích và thói quen sinh hoạt.',
              ),
              _FeatureCard(
                emoji: '🎓',
                title: 'Cộng đồng sinh viên',
                body: 'Cộng đồng dành riêng cho sinh viên để chia sẻ kinh nghiệm thuê trọ.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Cách SacoStay hoạt động',
      subtitle: 'Ba bước đơn giản để bắt đầu hành trình mới.',
      child: Column(
        children: [
          const _StepCard(
            number: '1',
            title: 'Tìm kiếm',
            body: 'Tìm phòng hoặc roommate phù hợp theo khu vực, trường học và ngân sách.',
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '2',
            title: 'Xác minh',
            body: 'Xem các tin đăng và chủ trọ đã được xác minh trên hệ thống.',
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '3',
            title: 'Kết nối',
            body: 'Liên hệ chủ trọ hoặc kết nối với roommate phù hợp.',
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: onSearch,
              style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
              child: const Text('Bắt đầu tìm kiếm'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: Colors.white,
      title: 'Không chỉ là nơi tìm phòng, đây còn là cộng đồng sinh viên.',
      child: Column(
        children: [
          const _CommunityCard(
            title: 'Thuê trọ an toàn',
            bullets: [
              'Những điều cần kiểm tra trước khi đặt cọc.',
              'Kinh nghiệm tránh lừa đảo khi tìm phòng.',
            ],
          ),
          const SizedBox(height: 12),
          const _CommunityCard(
            title: 'Roommate',
            bullets: [
              'Những yếu tố quan trọng khi chọn roommate.',
              'Kinh nghiệm sống chung hiệu quả.',
            ],
          ),
          const SizedBox(height: 12),
          const _CommunityCard(
            title: 'Student Life',
            bullets: [
              'Kinh nghiệm sống xa nhà.',
              'Quản lý chi tiêu sinh viên.',
              'Chuẩn bị cho kỳ thực tập.',
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: onDiscover,
              style: OutlinedButton.styleFrom(
                foregroundColor: SacoColors.sacoOrange,
                side: const BorderSide(color: SacoColors.sacoOrange),
              ),
              child: const Text('Khám phá cộng đồng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandlordSection extends StatelessWidget {
  const _LandlordSection({
    required this.landlordLink,
    required this.landlordQuery,
  });

  final String landlordLink;
  final Map<String, String>? landlordQuery;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Tiếp cận đúng sinh viên, tìm đúng người thuê.',
      subtitle: 'Dành cho chủ trọ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SacoStay giúp chủ trọ:',
            style: TextStyle(color: SacoColors.sacoGray),
          ),
          const SizedBox(height: 12),
          ...[
            'Tiếp cận cộng đồng sinh viên.',
            'Đăng tin dễ dàng.',
            'Nâng cao độ tin cậy thông qua xác minh.',
            'Kết nối đúng đối tượng có nhu cầu thuê.',
          ].map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✓ ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(t, style: const TextStyle(color: SacoColors.sacoGray))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (landlordQuery != null) {
                context.go(Uri(path: landlordLink, queryParameters: landlordQuery).toString());
              } else {
                context.go(landlordLink);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
            child: const Text('Đăng tin ngay'),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SacoColors.sacoOrange, SacoColors.sacoOrangeDark],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Hàng nghìn sinh viên đang tìm phòng trọ gần trường học mỗi tháng. Hãy để SacoStay giúp bạn tiếp cận đúng đối tượng.',
              style: TextStyle(color: Colors.white, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: Colors.white,
      title: 'Xây dựng niềm tin cùng SacoStay',
      child: Column(
        children: const [
          _TrustCard(
            title: 'Tin đăng được kiểm duyệt',
            body: 'Mọi tin đăng đều trải qua quá trình kiểm tra trước khi hiển thị.',
          ),
          SizedBox(height: 12),
          _TrustCard(
            title: 'Chủ trọ được xác minh',
            body: 'SacoStay ưu tiên các chủ trọ đã xác minh thông tin.',
          ),
          SizedBox(height: 12),
          _TrustCard(
            title: 'Bảo vệ cộng đồng sinh viên',
            body: 'Tạo môi trường tìm kiếm nơi ở minh bạch và an toàn hơn.',
          ),
          SizedBox(height: 12),
          _TrustCard(
            title: 'Hỗ trợ người dùng',
            body: 'Người dùng có thể báo cáo những tin đăng không phù hợp hoặc đáng ngờ.',
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({
    required this.expandedId,
    required this.onToggle,
  });

  final String? expandedId;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Câu hỏi thường gặp',
      subtitle: 'Giải đáp nhanh — chọn câu hỏi để xem chi tiết.',
      child: Column(
        children: homeFaqItems.map((item) {
          final open = expandedId == item.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.shade100),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        item.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: SacoColors.sacoBlue,
                        ),
                      ),
                      trailing: Text(
                        open ? '−' : '+',
                        style: const TextStyle(
                          fontSize: 20,
                          color: SacoColors.sacoOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => onToggle(item.id),
                    ),
                    if (open)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.shortAnswer,
                              style: const TextStyle(color: SacoColors.sacoGray),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => context.go(item.detailPath),
                              child: Text(
                                '${item.ctaLabel} →',
                                style: const TextStyle(
                                  color: SacoColors.sacoOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection({
    required this.landlordLink,
    required this.landlordQuery,
  });

  final String landlordLink;
  final Map<String, String>? landlordQuery;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final studentCard = _CtaCard(
            title: 'Dành cho sinh viên',
            body: 'Bạn đã sẵn sàng tìm đúng người và chọn đúng nơi chưa?',
            primary: true,
            buttonLabel: 'Tìm phòng ngay',
            onPressed: () => context.go('/rooms'),
          );
          final landlordCard = _CtaCard(
            title: 'Dành cho chủ trọ',
            body: 'Tiếp cận cộng đồng sinh viên ngay hôm nay.',
            primary: false,
            buttonLabel: 'Đăng tin ngay',
            onPressed: () {
              if (landlordQuery != null) {
                context.go(Uri(path: landlordLink, queryParameters: landlordQuery).toString());
              } else {
                context.go(landlordLink);
              }
            },
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: studentCard),
                const SizedBox(width: 16),
                Expanded(child: landlordCard),
              ],
            );
          }

          return Column(
            children: [
              studentCard,
              const SizedBox(height: 16),
              landlordCard,
            ],
          );
        },
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.child,
    this.title,
    this.subtitle,
    this.background,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background ?? SacoColors.pageBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: SacoColors.sacoBlue,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SacoColors.sacoGray),
            ),
          ],
          if (title != null) const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SacoColors.pageBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: SacoColors.sacoBlue)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: SacoColors.sacoGray, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: SacoColors.sacoOrange,
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: SacoColors.sacoBlue)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: SacoColors.sacoGray, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SacoColors.pageBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: SacoColors.sacoOrange)),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: SacoColors.sacoOrange)),
                  Expanded(child: Text(b, style: const TextStyle(color: SacoColors.sacoGray, fontSize: 13))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SacoColors.pageBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: SacoColors.sacoBlue)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: SacoColors.sacoGray, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    required this.primary,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: SacoColors.sacoBlue)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: SacoColors.sacoGray)),
          const SizedBox(height: 16),
          if (primary)
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
              child: Text(buttonLabel),
            )
          else
            OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: SacoColors.sacoOrange,
                side: const BorderSide(color: SacoColors.sacoOrange),
              ),
              child: Text(buttonLabel),
            ),
        ],
      ),
    );
  }
}
