import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/utils/listing_display.dart';
import '../../models/room_post.dart';
import '../../repositories/room_post_repository.dart';
import '../../shared/widgets/saco_landlord_ui.dart';
import '../payment/payment_config.dart';
import '../payment/payment_launcher.dart';

class LandlordPricingScreen extends ConsumerStatefulWidget {
  const LandlordPricingScreen({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<LandlordPricingScreen> createState() => _LandlordPricingScreenState();
}

class _LandlordPricingScreenState extends ConsumerState<LandlordPricingScreen> {
  final _pageController = PageController(viewportFraction: 0.88);
  int _pageIndex = 0;
  String? _roomPostId;
  bool _loadingPosts = false;
  String? _payingPackage;
  String? _errorMessage;

  static const _packages = [
    _LandlordPackageCardData(
      tierLabel: 'BASIC',
      title: 'GÓI CƠ BẢN',
      subtitle: 'Gói Cơ Bản',
      price: '53.000 VND',
      color: Color(0xFF9CA3AF),
      package: PaymentCheckoutPackage.landlordBasic,
      benefits: [
        'Kích thước tin nhỏ',
        'Hiển thị trên danh sách & bản đồ',
        'Thanh toán theo tin đăng',
      ],
    ),
    _LandlordPackageCardData(
      tierLabel: 'LITE',
      title: 'GÓI LITE',
      subtitle: 'Gói Lite',
      price: '295.000 VND',
      color: Color(0xFF2563EB),
      package: PaymentCheckoutPackage.landlordLite,
      benefits: [
        'Nhãn dán nổi bật màu xanh',
        'Kích thước tin vừa',
        'Ưu tiên duyệt 30–60 phút',
        'Duy trì thêm 10 ngày tin thường',
        'Bộ lọc & phân tích người xem',
      ],
    ),
    _LandlordPackageCardData(
      tierLabel: 'PRO',
      title: 'GÓI PRO',
      subtitle: 'Gói Pro',
      price: '737.500 VND',
      color: Color(0xFFF59E0B),
      package: PaymentCheckoutPackage.landlordPro,
      benefits: [
        'Nhãn dán màu cam, in hoa',
        'Kích thước tin lớn',
        'Ưu tiên duyệt 30–60 phút',
        'Đẩy tin nổi bật',
        'Bộ lọc nâng cao',
      ],
    ),
    _LandlordPackageCardData(
      tierLabel: 'ELITE',
      title: 'GÓI ELITE',
      subtitle: 'Gói Elite',
      price: '1.475.000 VND',
      color: Color(0xFFEF4444),
      package: PaymentCheckoutPackage.landlordElite,
      benefits: [
        'Nhãn dán màu đỏ, in hoa',
        'Kích thước tin rất lớn',
        'Ưu tiên duyệt 30–60 phút',
        'Đẩy tin & phân tích người xem',
        'Hiển thị nổi bật nhất trên bản đồ',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _roomPostId = widget.postId;
    if (_roomPostId == null || _roomPostId!.isEmpty) {
      _resolvePostId();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _resolvePostId() async {
    setState(() => _loadingPosts = true);
    try {
      final posts = await ref.read(roomPostRepositoryProvider).getMyPosts();
      RoomPostSummary? pending;
      for (final p in posts) {
        if (isListingPendingPayment(p.status) ||
            isListingPendingApproval(p.status) ||
            (p.status ?? '').isEmpty) {
          pending = p;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _roomPostId = pending?.id ?? (posts.isNotEmpty ? posts.first.id : '');
        _loadingPosts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _pay(PaymentCheckoutPackage pkg) async {
    final postId = _roomPostId ?? '';
    if (postId.isEmpty) {
      setState(() {
        _errorMessage =
            'Chưa có tin đăng để thanh toán. Hãy đăng tin trước hoặc chọn tin từ Tin đã đăng.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _payingPackage = pkg.label;
    });
    await launchLandlordPackagePayment(
      context: context,
      ref: ref,
      roomPostId: postId,
      packageName: pkg.label,
    );
    if (mounted) setState(() => _payingPackage = null);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _roomPostId != null && _roomPostId!.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacoPageHeader(
            title: 'Đăng ký gói thành viên',
            subtitle: _roomPostId != null && _roomPostId!.isNotEmpty
                ? 'Nâng cấp tin đăng để tiếp cận nhiều người thuê hơn'
                : 'Chọn gói phù hợp — tin VIP hiển thị nổi bật trên bản đồ & danh sách',
          ),
          if (_loadingPosts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Đang tìm tin đăng…',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
              ),
            )
          else if (!enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Chưa có tin. Đăng tin trước khi thanh toán gói VIP.',
                style: TextStyle(fontSize: 13, color: Colors.red.shade700),
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(_errorMessage!, style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 560,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _packages.length,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (_, i) {
                final pkg = _packages[i];
                final paying = _payingPackage == pkg.package.label;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _PackageCarouselCard(
                    data: pkg,
                    enabled: enabled,
                    paying: paying,
                    onPay: () => _pay(pkg.package),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _packages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _pageIndex == i ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _pageIndex == i ? SacoColors.sacoOrange : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              '(*) Các tin VIP sẽ được ưu tiên kiểm duyệt trong thời gian 30–60 phút. Vuốt ngang để xem các gói khác.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandlordPackageCardData {
  const _LandlordPackageCardData({
    required this.tierLabel,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.color,
    required this.package,
    required this.benefits,
  });

  final String tierLabel;
  final String title;
  final String subtitle;
  final String price;
  final Color color;
  final PaymentCheckoutPackage package;
  final List<String> benefits;
}

class _PackageCarouselCard extends StatelessWidget {
  const _PackageCarouselCard({
    required this.data,
    required this.enabled,
    required this.paying,
    required this.onPay,
  });

  final _LandlordPackageCardData data;
  final bool enabled;
  final bool paying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            data.color.withValues(alpha: 0.15),
            Colors.white,
          ],
        ),
        border: Border.all(color: data.color.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.color.withValues(alpha: 0.15),
                border: Border.all(color: data.color, width: 2),
              ),
              child: Icon(Icons.workspace_premium, color: data.color, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: data.color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.subtitle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: data.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data.tierLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: data.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.price,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: data.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CÁC QUYỀN LỢI BAO GỒM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: data.benefits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: data.color.withValues(alpha: 0.15),
                              ),
                              child: Icon(Icons.check, size: 14, color: data.color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data.benefits[i],
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: !enabled || paying ? null : onPay,
                style: FilledButton.styleFrom(
                  backgroundColor: data.color,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  paying ? 'Đang xử lý…' : 'Thanh toán ${data.tierLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
