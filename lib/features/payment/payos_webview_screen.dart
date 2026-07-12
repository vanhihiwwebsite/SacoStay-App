import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme.dart';
import '../../core/payment/payment_return.dart';
import 'payment_config.dart';

class PayOsWebViewScreen extends StatefulWidget {
  const PayOsWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentContext,
    this.package,
    this.postId,
  });

  final String paymentUrl;
  final PaymentContext paymentContext;
  final String? package;
  final String? postId;

  @override
  State<PayOsWebViewScreen> createState() => _PayOsWebViewScreenState();
}

class _PayOsWebViewScreenState extends State<PayOsWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (_handleReturnUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _handleReturnUrl(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _handleReturnUrl(String url) {
    if (_handled) return true;

    final parsed = tryParsePaymentReturnUrl(url);
    if (parsed == null) return false;

    // BE /payos-return redirects to web /payment/result — wait for that URL.
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('/payos-return') && !uri.path.contains('/payment/result')) {
      return false;
    }

    _handled = true;
    _goToResult(parsed);
    return true;
  }

  void _goToResult(PaymentReturnInfo info) {
    PaymentContextStorage.clear();
    final params = <String, String>{
      'status': paymentResultStatusQuery(info.status),
      'context': info.context.queryValue,
      if (info.orderId.isNotEmpty) 'orderId': info.orderId,
      if ((info.package ?? widget.package)?.isNotEmpty == true)
        'package': info.package ?? widget.package!,
      if ((info.postId ?? widget.postId)?.isNotEmpty == true)
        'postId': info.postId ?? widget.postId!,
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(Uri(path: '/payment/result', queryParameters: params).toString());
    });
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy thanh toán?'),
        content: const Text('Giao dịch sẽ không được hoàn tất nếu bạn thoát bây giờ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _handled = true;
      _goToResult(
        PaymentReturnInfo(
          status: PaymentResultStatus.cancelled,
          context: widget.paymentContext,
          orderId: '',
          package: widget.package,
          postId: widget.postId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán PayOS'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmCancel,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
