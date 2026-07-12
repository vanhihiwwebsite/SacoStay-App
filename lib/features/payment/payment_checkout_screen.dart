import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/payment/payment_return.dart';
import '../../repositories/payment_repository.dart';
import 'payment_config.dart';
import 'payment_launcher.dart';

class PaymentCheckoutScreen extends ConsumerStatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.package,
    required this.contextType,
    this.postId,
  });

  final PaymentCheckoutPackage package;
  final PaymentContext contextType;
  final String? postId;

  @override
  ConsumerState<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends ConsumerState<PaymentCheckoutScreen> {
  bool _processing = false;
  String? _error;

  String get _amountFmt {
    final n = widget.package.amount;
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buf.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buf.write('.');
    }
    return '${buf}đ';
  }

  Future<void> _pay() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final repo = ref.read(paymentRepositoryProvider);
      final url = widget.contextType == PaymentContext.landlord
          ? await repo.buyLandlordPackage(
              roomPostId: widget.postId ?? '',
              packageName: widget.package.label,
            )
          : await repo.buyTenantPremium(packageName: widget.package.label);

      await PaymentContextStorage.save(
        context: widget.contextType,
        postId: widget.postId,
        package: widget.package.label,
      );

      if (!mounted) return;
      setState(() => _processing = false);
      await context.push(
        '/payment/payos',
        extra: PayOsLaunchArgs(
          paymentUrl: url,
          paymentContext: widget.contextType,
          package: widget.package.label,
          postId: widget.postId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e is ApiException ? e.message : 'Không tạo được link thanh toán.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: SacoColors.sacoOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 36,
                    color: SacoColors.sacoOrange,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thanh toán PayOS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.package.title,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Text(
                  _amountFmt,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: SacoColors.sacoBlue,
                  ),
                ),
                if (widget.postId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tin đăng: ${widget.postId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _PayMethodTile(
            icon: Icons.qr_code_2,
            title: 'QR PayOS / Ngân hàng',
            subtitle: 'Quét mã hoặc chuyển khoản qua PayOS',
            selected: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _processing ? null : _pay,
            style: FilledButton.styleFrom(
              backgroundColor: SacoColors.sacoOrange,
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_processing ? 'Đang tạo link…' : 'Thanh toán $_amountFmt'),
          ),
          TextButton(
            onPressed: _processing ? null : () => context.pop(),
            child: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }
}

class _PayMethodTile extends StatelessWidget {
  const _PayMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? SacoColors.sacoOrange : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? SacoColors.sacoOrange : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle, color: SacoColors.sacoOrange),
        ],
      ),
    );
  }
}
