import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../features/auth/auth_provider.dart';
import '../payment/payment_launcher.dart';
import '../../repositories/lifestyle_repository.dart';

class TenantPricingScreen extends ConsumerStatefulWidget {
  const TenantPricingScreen({super.key});

  @override
  ConsumerState<TenantPricingScreen> createState() => _TenantPricingScreenState();
}

class _TenantPricingScreenState extends ConsumerState<TenantPricingScreen> {
  bool _loading = true;
  bool _isPremium = false;
  bool _paying = false;
  String? _payError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _isPremium = false;
      });
      return;
    }
    final quota = await ref.read(lifestyleRepositoryProvider).getSwipeQuota();
    setState(() {
      _isPremium = quota.isPremium;
      _loading = false;
    });
  }

  Future<void> _upgrade() async {
    if (!ref.read(authControllerProvider).isLoggedIn) {
      context.go('/login?returnUrl=/tenant-pricing');
      return;
    }
    setState(() {
      _payError = null;
      _paying = true;
    });
    await launchTenantPremiumPayment(context: context, ref: ref);
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '👑 NÂNG CẤP PREMIUM',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SacoColors.sacoOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tìm bạn ở ghép nhanh hơn',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Nâng cấp Premium để swipe không giới hạn và nhắn tin trực tiếp',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (_payError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _payError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          _planCard(
            title: 'FREEMIUM',
            price: 'Miễn phí',
            highlight: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('• 5 lượt matching / tuần'),
                const Text('• Xem phòng trọ & bộ lọc cơ bản'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/discovery'),
                  child: const Text('Tiếp tục Free'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _planCard(
            title: 'PREMIUM',
            price: '80k/tháng',
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('• Matching không giới hạn'),
                const Text('• Xem hồ sơ & lối sống chi tiết'),
                const Text('• Nhắn tin trực tiếp'),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_isPremium)
                  const Text(
                    '✓ Đang sử dụng Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  FilledButton(
                    onPressed: _paying ? null : _upgrade,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFBD59),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(_paying ? 'Đang tạo link…' : '⚡ Nâng cấp Premium'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required bool highlight,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? SacoColors.sacoOrange : Colors.grey.shade300,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: highlight ? SacoColors.sacoOrange : Colors.black,
            ),
          ),
          Text(price, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
