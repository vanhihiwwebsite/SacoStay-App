import 'package:dio/dio.dart';

import '../../config/environment.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStorage});

  final TokenStorage tokenStorage;

  void Function()? onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    void Function()? onUnauthorized,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Environment.apiUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );

    final interceptor = AuthInterceptor(tokenStorage: tokenStorage);
    interceptor.onUnauthorized = onUnauthorized;
    _dio.interceptors.add(interceptor);
  }

  late final Dio _dio;

  Dio get dio => _dio;
}
