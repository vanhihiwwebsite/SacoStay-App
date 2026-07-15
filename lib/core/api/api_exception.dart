import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.isBanned = false,
  });

  final String message;
  final int? statusCode;
  final bool isBanned;

  @override
  String toString() => message;
}

String getApiErrorMessage(dynamic error) {
  if (error is ApiException) return error.message;
  return 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
}

/// Trích message từ phản hồi lỗi Dio (400/401/…) — giống web `getApiErrorMessage`.
String? extractDioErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    for (final key in ['message', 'Message', 'detail', 'title']) {
      final v = map[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
  }
  if (data is List) {
    final parts = data
        .map((item) {
          if (item is Map) {
            final desc = item['description'] ?? item['message'];
            return desc?.toString().trim() ?? '';
          }
          return '';
        })
        .where((s) => s.isNotEmpty)
        .join(', ');
    if (parts.isNotEmpty) return parts;
  }
  return null;
}

({String message, bool isBanned}) loginErrorFromApi({
  int? statusCode,
  String? apiMessage,
  String? networkMessage,
}) {
  const bannedMessage =
      'Tài khoản của bạn đã bị khóa vĩnh viễn do vi phạm nội quy SacoStay.';
  final apiMsg = (apiMessage ?? '').trim();

  final looksBanned = statusCode == 400 &&
      (RegExp(r'khóa|khoa|vi phạm|vi pham|bị ban|bi ban|locked|lockout', caseSensitive: false)
              .hasMatch(apiMsg) ||
          apiMsg.isEmpty);

  if (looksBanned) {
    final message = apiMsg.isNotEmpty && RegExp(r'khóa|vi phạm', caseSensitive: false).hasMatch(apiMsg)
        ? apiMsg
        : bannedMessage;
    return (message: message, isBanned: true);
  }

  if (statusCode == 401) {
    return (
      message: 'Email, tên đăng nhập, số điện thoại hoặc mật khẩu không đúng.',
      isBanned: false
    );
  }

  if (statusCode == null || statusCode == 0) {
    return (
      message: networkMessage ??
          'Không kết nối được máy chủ. Kiểm tra kết nối mạng hoặc backend.',
      isBanned: false
    );
  }

  if (apiMsg.isNotEmpty && !RegExp(r'Http failure|Unknown Error', caseSensitive: false).hasMatch(apiMsg)) {
    return (message: apiMsg, isBanned: false);
  }

  return (message: 'Đăng nhập thất bại. Vui lòng thử lại sau.', isBanned: false);
}
