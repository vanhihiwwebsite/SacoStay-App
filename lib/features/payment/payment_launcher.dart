import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/payment/payment_return.dart';
import '../../repositories/payment_repository.dart';
import 'payment_config.dart';

class PayOsLaunchArgs {
  const PayOsLaunchArgs({
    required this.paymentUrl,
    required this.paymentContext,
    this.package,
    this.postId,
  });

  final String paymentUrl;
  final PaymentContext paymentContext;
  final String? package;
  final String? postId;
}

Future<void> launchLandlordPackagePayment({
  required BuildContext context,
  required WidgetRef ref,
  required String roomPostId,
  required String packageName,
}) {
  return _launch(
    context: context,
    ref: ref,
    paymentContext: PaymentContext.landlord,
    package: packageName,
    postId: roomPostId,
    createUrl: () => ref.read(paymentRepositoryProvider).buyLandlordPackage(
          roomPostId: roomPostId,
          packageName: packageName,
        ),
  );
}

Future<void> launchTenantPremiumPayment({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return _launch(
    context: context,
    ref: ref,
    paymentContext: PaymentContext.tenant,
    package: PaymentCheckoutPackage.tenantPremium.label,
    createUrl: () => ref.read(paymentRepositoryProvider).buyTenantPremium(),
  );
}

Future<void> _launch({
  required BuildContext context,
  required WidgetRef ref,
  required PaymentContext paymentContext,
  required Future<String> Function() createUrl,
  String? package,
  String? postId,
}) async {
  await PaymentContextStorage.save(
    context: paymentContext,
    postId: postId,
    package: package,
  );

  try {
    final url = await createUrl();
    if (!context.mounted) return;
    if (url.isEmpty) {
      _showError(context, 'Không nhận được link thanh toán PayOS.');
      return;
    }
    await context.push(
      '/payment/payos',
      extra: PayOsLaunchArgs(
        paymentUrl: url,
        paymentContext: paymentContext,
        package: package,
        postId: postId,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    final msg = e is ApiException
        ? e.message
        : e is UnsupportedError
            ? 'Thanh toán chưa được bật trên app.'
            : 'Không tạo được link thanh toán. Vui lòng thử lại.';
    _showError(context, msg);
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
