import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../features/auth/auth_provider.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider).dio);
});

class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  Future<String> buyTenantPremium({String packageName = 'PREMIUM'}) async {
    final response = await _dio.post<dynamic>(
      '/Payment/buy-tenant-package',
      data: {
        'packageName': packageName.toUpperCase(),
        'PackageName': packageName.toUpperCase(),
      },
    );
    final url = _paymentUrlFromResponse(response.data);
    if (url.isEmpty) {
      throw Exception('Không nhận được link thanh toán');
    }
    return url;
  }

  String _paymentUrlFromResponse(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is! Map) return '';
    final o = Map<String, dynamic>.from(raw);
    final nested = o['data'] is Map ? Map<String, dynamic>.from(o['data'] as Map) : o;
    return strField(
      pickField(nested, 'paymentUrl', ['PaymentUrl', 'url', 'Url']),
    );
  }
}
