import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import 'payment_config.dart';

class PaymentCheckoutScreen extends StatefulWidget {
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
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  bool _processing = false;

  Future<void> _simulatePay({required bool success}) async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final orderId = 'DEMO-${DateTime.now().millisecondsSinceEpoch}';
    final status = success ? 'success' : 'failed';
    final params = <String, String>{
      'status': status,
      'context': widget.contextType.queryValue,
      'orderId': orderId,
      'package': widget.package.label,
    };
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      params['postId'] = widget.postId!;
    }
    context.go(Uri(path: '/payment/result', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    final amountFmt =
        '${widget.package.amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chế độ demo: không gọi API PayOS. Backend payment đang bảo trì.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                  'PayOS Checkout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.package.title,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Text(
                  amountFmt,
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
            subtitle: 'Quét mã hoặc chuyển khoản (demo UI)',
            selected: true,
          ),
          _PayMethodTile(
            icon: Icons.credit_card,
            title: 'Thẻ nội địa / quốc tế',
            subtitle: 'Sẽ kích hoạt khi backend sẵn sàng',
            selected: false,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _processing ? null : () => _simulatePay(success: true),
            style: FilledButton.styleFrom(
              backgroundColor: SacoColors.sacoOrange,
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_processing ? 'Đang xử lý…' : 'Thanh toán $amountFmt'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _processing ? null : () => _simulatePay(success: false),
            child: const Text('Mô phỏng thanh toán thất bại'),
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
