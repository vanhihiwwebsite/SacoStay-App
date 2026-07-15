import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/utils/kyc_upload.dart';
import '../core/utils/kyc_display.dart';
import '../features/auth/auth_provider.dart';
import '../models/kyc.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return KycRepository(ref.watch(apiClientProvider).dio);
});

class KycRepository {
  KycRepository(this._dio);

  final Dio _dio;

  Future<KycStatus> getMyStatus() async {
    try {
      final response = await _dio.get<dynamic>('/Kyc/my-status');
      return normalizeKycStatus(response.data);
    } catch (_) {
      return const KycStatus(status: KycApiStatus.notSubmitted);
    }
  }

  Future<String> submit({
    required String frontIdPath,
    required String backIdPath,
    required String selfieVideoPath,
  }) async {
    final frontErr = validateKycIdImagePath(frontIdPath);
    if (frontErr != null) throw ApiException(message: frontErr);
    final backErr = validateKycIdImagePath(backIdPath);
    if (backErr != null) throw ApiException(message: backErr);
    final videoErr = validateKycVideoPath(selfieVideoPath);
    if (videoErr != null) throw ApiException(message: videoErr);

    final fd = FormData();
    fd.files.addAll([
      MapEntry('FrontIdImage', await kycImageMultipart(frontIdPath, 'front_id')),
      MapEntry('BackIdImage', await kycImageMultipart(backIdPath, 'back_id')),
      MapEntry('SelfieVideo', await kycVideoMultipart(selfieVideoPath)),
    ]);

    try {
      final response = await _dio.post<dynamic>('/Kyc/submit', data: fd);
      return _parseSubmitMessage(response.data);
    } on DioException catch (e) {
      throw ApiException(
        message: extractDioErrorMessage(e) ??
            'Xác thực thất bại. Vui lòng thử lại.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  String _parseSubmitMessage(dynamic raw) {
    if (raw is String) {
      final t = raw.trim();
      if (!t.startsWith('{')) {
        return t.isEmpty ? 'Xác minh danh tính thành công.' : t;
      }
    }
    if (raw is Map) {
      final o = Map<String, dynamic>.from(raw);
      final msg = (o['message'] ?? o['Message'] ?? '').toString().trim();
      if (msg.isNotEmpty) return msg;
    }
    return 'Xác minh danh tính thành công.';
  }
}
