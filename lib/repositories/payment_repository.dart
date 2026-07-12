import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/utils/json_normalize.dart';
import '../features/auth/auth_provider.dart';
import '../features/payment/payment_config.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider).dio);
});

class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  String _paymentUrlFromResponse(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is! Map) return '';
    final o = Map<String, dynamic>.from(raw);
    final nested = o['data'] is Map ? Map<String, dynamic>.from(o['data'] as Map) : o;
    return strField(
      pickField(nested, 'paymentUrl', ['PaymentUrl', 'url', 'Url', 'checkoutUrl', 'CheckoutUrl']),
    );
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final o = Map<String, dynamic>.from(data);
      final msg = strField(pickField(o, 'message', ['Message', 'error', 'Error']));
      if (msg.isNotEmpty) return msg;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Không kết nối được máy chủ thanh toán.';
    }
    return 'Không tạo được link thanh toán PayOS.';
  }

  Future<String> buyTenantPremium({String packageName = 'PREMIUM'}) async {
    if (kPaymentUiOnlyMode) {
      throw UnsupportedError('payment_ui_only');
    }
    try {
      final response = await _dio.post<dynamic>(
        '/Payment/buy-tenant-package',
        data: {
          'packageName': packageName.toUpperCase(),
          'PackageName': packageName.toUpperCase(),
        },
      );
      final url = _paymentUrlFromResponse(response.data);
      if (url.isEmpty) {
        throw ApiException(message: 'Không nhận được link thanh toán');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException(
        message: _messageFromDio(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<String> buyLandlordPackage({
    required String roomPostId,
    required String packageName,
  }) async {
    if (kPaymentUiOnlyMode) {
      throw UnsupportedError('payment_ui_only');
    }
    try {
      final response = await _dio.post<dynamic>(
        '/Payment/buy-landlord-package',
        data: {
          'roomPostId': roomPostId,
          'RoomPostId': roomPostId,
          'packageName': packageName.toUpperCase(),
          'PackageName': packageName.toUpperCase(),
        },
      );
      final url = _paymentUrlFromResponse(response.data);
      if (url.isEmpty) {
        throw ApiException(message: 'Không nhận được link thanh toán');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException(
        message: _messageFromDio(e),
        statusCode: e.response?.statusCode,
      );
    }
  }
}
