import '../../features/payment/payment_config.dart';

enum PaymentResultStatus { success, failed, cancelled, unknown }

/// Parse query from BE redirect or PayOS callback.
PaymentReturnInfo parsePaymentReturnParams(Map<String, String> qp) {
  final cancelFlag = (qp['cancel'] ?? '').toLowerCase() == 'true';
  final statusRaw = (qp['status'] ?? '').toLowerCase();

  PaymentResultStatus status = PaymentResultStatus.unknown;
  if (cancelFlag ||
      statusRaw == 'cancelled' ||
      statusRaw == 'cancel') {
    status = PaymentResultStatus.cancelled;
  } else if (statusRaw == 'success' || statusRaw == 'paid') {
    status = PaymentResultStatus.success;
  } else if (statusRaw == 'failed') {
    status = PaymentResultStatus.failed;
  }

  final ctxParam = (qp['context'] ?? '').toLowerCase();
  PaymentContext context;
  if (ctxParam == 'tenant') {
    context = PaymentContext.tenant;
  } else if (ctxParam == 'landlord') {
    context = PaymentContext.landlord;
  } else {
    context = PaymentContextStorage.readContext() ?? PaymentContext.landlord;
  }

  final orderId = (qp['orderId'] ?? qp['orderCode'] ?? '').trim();
  final package = qp['package'] ?? PaymentContextStorage.readPackage() ?? '';
  final postId = qp['postId'] ?? PaymentContextStorage.readPostId() ?? '';

  return PaymentReturnInfo(
    status: status,
    context: context,
    orderId: orderId,
    package: package.isEmpty ? null : package,
    postId: postId.isEmpty ? null : postId,
  );
}

String paymentReturnPath(PaymentContext context, PaymentResultStatus status) {
  if (context == PaymentContext.tenant) {
    return status == PaymentResultStatus.success ? '/discovery' : '/tenant-pricing';
  }
  return status == PaymentResultStatus.success ? '/my-listings' : '/landlord-pricing';
}

String paymentResultStatusQuery(PaymentResultStatus status) {
  switch (status) {
    case PaymentResultStatus.success:
      return 'success';
    case PaymentResultStatus.failed:
      return 'failed';
    case PaymentResultStatus.cancelled:
      return 'cancelled';
    case PaymentResultStatus.unknown:
      return 'unknown';
  }
}

class PaymentReturnInfo {
  const PaymentReturnInfo({
    required this.status,
    required this.context,
    required this.orderId,
    this.package,
    this.postId,
  });

  final PaymentResultStatus status;
  final PaymentContext context;
  final String orderId;
  final String? package;
  final String? postId;
}

/// Returns parsed payment result if [url] is a PayOS/FE return URL.
PaymentReturnInfo? tryParsePaymentReturnUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final path = uri.path.toLowerCase();
  if (!path.contains('/payment/result') &&
      !path.contains('/payment/payos-return') &&
      !path.endsWith('/payos-return')) {
    return null;
  }

  final qp = uri.queryParameters.map((k, v) => MapEntry(k, v));
  if (path.contains('/payment/result')) {
    return parsePaymentReturnParams(qp);
  }

  // BE payos-return — let WebView follow redirect; only parse if params present.
  if (qp.containsKey('orderCode') || qp.containsKey('status') || qp.containsKey('cancel')) {
    final mapped = Map<String, String>.from(qp);
    mapped.putIfAbsent('orderId', () => qp['orderCode'] ?? '');
    return parsePaymentReturnParams(mapped);
  }
  return null;
}

/// Persist payment context before opening PayOS (mirrors web sessionStorage).
class PaymentContextStorage {
  PaymentContextStorage._();

  static PaymentContext? _context;
  static String? _postId;
  static String? _package;

  static Future<void> save({
    required PaymentContext context,
    String? postId,
    String? package,
  }) async {
    _context = context;
    _postId = postId;
    _package = package;
  }

  static PaymentContext? readContext() => _context;

  static String? readPostId() => _postId;

  static String? readPackage() => _package;

  static void clear() {
    _context = null;
    _postId = null;
    _package = null;
  }
}
