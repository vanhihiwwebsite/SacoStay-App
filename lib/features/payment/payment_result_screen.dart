import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import 'payment_config.dart';

class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    super.key,
    required this.status,
    this.contextType,
    this.orderId,
    this.package,
    this.postId,
  });

  final String status;
  final PaymentContext? contextType;
  final String? orderId;
  final String? package;
  final String? postId;

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get isPending => status.toLowerCase() == 'pending';

  @override
  Widget build(BuildContext context) {
    final icon = isSuccess
        ? Icons.check_circle_outline
        : isPending
            ? Icons.hourglass_top_outlined
            : Icons.error_outline;
    final color = isSuccess
        ? Colors.green
        : isPending
            ? Colors.orange
            : Colors.red;
    final title = isSuccess
        ? 'Thanh toán thành công'
        : isPending
            ? 'Đang xử lý thanh toán'
            : 'Thanh toán thất bại';

    String subtitle;
    if (kPaymentUiOnlyMode) {
      subtitle = isSuccess
          ? 'Đây là kết quả demo. Khi backend PayOS hoạt động, gói sẽ được kích hoạt tự động.'
          : 'Giao dịch chưa hoàn tất. Vui lòng thử lại sau khi backend payment sẵn sàng.';
    } else {
      subtitle = isSuccess
          ? 'Gói của bạn sẽ được kích hoạt trong giây lát.'
          : 'Vui lòng thử lại hoặc liên hệ hỗ trợ.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              _InfoRow(label: 'Mã đơn', value: orderId ?? '—'),
              _InfoRow(label: 'Gói', value: package ?? '—'),
              _InfoRow(
                label: 'Loại',
                value: contextType == PaymentContext.landlord
                    ? 'Chủ trọ VIP'
                    : 'Tenant Premium',
              ),
              if (postId != null && postId!.isNotEmpty)
                _InfoRow(label: 'Tin đăng', value: postId!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (contextType == PaymentContext.landlord) {
                    context.go('/my-listings');
                  } else {
                    context.go('/discovery');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Tiếp tục'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
