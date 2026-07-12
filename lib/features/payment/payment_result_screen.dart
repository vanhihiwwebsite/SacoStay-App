import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/payment/payment_return.dart';
import '../../features/auth/auth_provider.dart';
import 'payment_config.dart';

class PaymentResultScreen extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  @override
  void initState() {
    super.initState();
    PaymentContextStorage.clear();
    if (_isSuccess && widget.contextType == PaymentContext.tenant) {
      Future.microtask(() => ref.read(authControllerProvider.notifier).refreshProfile());
    }
  }

  bool get _isSuccess => widget.status.toLowerCase() == 'success';
  bool get _isCancelled =>
      widget.status.toLowerCase() == 'cancelled' || widget.status.toLowerCase() == 'cancel';
  bool get _isPending => widget.status.toLowerCase() == 'pending';

  String get _title {
    if (_isSuccess) return 'Thanh toán thành công';
    if (_isCancelled) return 'Đã hủy thanh toán';
    if (_isPending) return 'Đang xử lý thanh toán';
    return 'Thanh toán thất bại';
  }

  String get _subtitle {
    if (_isSuccess && widget.contextType == PaymentContext.landlord) {
      return 'Gói tin đã được kích hoạt. Tin đăng chuyển sang chờ admin duyệt (nếu là tin mới).';
    }
    if (_isSuccess && widget.contextType == PaymentContext.tenant) {
      return 'Bạn đã nâng cấp Premium. Tận hưởng matching không giới hạn!';
    }
    if (_isCancelled) {
      return 'Bạn đã hủy giao dịch. Không có khoản phí nào được trừ.';
    }
    if (_isPending) {
      return 'Giao dịch đang được xử lý. Vui lòng kiểm tra lại sau vài phút.';
    }
    return 'Giao dịch không thành công. Bạn có thể thử lại.';
  }

  IconData get _icon {
    if (_isSuccess) return Icons.check_circle_outline;
    if (_isCancelled || _isPending) return Icons.hourglass_top_outlined;
    return Icons.error_outline;
  }

  Color get _color {
    if (_isSuccess) return Colors.green;
    if (_isCancelled || _isPending) return Colors.orange;
    return Colors.red;
  }

  void _continue() {
    final ctx = widget.contextType ?? PaymentContext.landlord;
    PaymentResultStatus st;
    if (_isSuccess) {
      st = PaymentResultStatus.success;
    } else if (_isCancelled) {
      st = PaymentResultStatus.cancelled;
    } else if (_isPending) {
      st = PaymentResultStatus.unknown;
    } else {
      st = PaymentResultStatus.failed;
    }
    final path = paymentReturnPath(ctx, st);
    if (path == '/my-listings' && widget.postId != null && widget.postId!.isNotEmpty) {
      context.go('${path}?payment=completed&roomPostId=${Uri.encodeComponent(widget.postId!)}');
    } else {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 80, color: _color),
              const SizedBox(height: 16),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              _InfoRow(label: 'Mã đơn', value: widget.orderId ?? '—'),
              _InfoRow(label: 'Gói', value: widget.package ?? '—'),
              _InfoRow(
                label: 'Loại',
                value: widget.contextType == PaymentContext.landlord
                    ? 'Chủ trọ VIP'
                    : 'Tenant Premium',
              ),
              if (widget.postId != null && widget.postId!.isNotEmpty)
                _InfoRow(label: 'Tin đăng', value: widget.postId!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _continue,
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
