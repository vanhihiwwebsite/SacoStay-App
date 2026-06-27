import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final fd = FormData.fromMap({
      'FrontIdImage': await MultipartFile.fromFile(
        frontIdPath,
        filename: 'front_id.jpg',
      ),
      'BackIdImage': await MultipartFile.fromFile(
        backIdPath,
        filename: 'back_id.jpg',
      ),
      'SelfieVideo': await MultipartFile.fromFile(
        selfieVideoPath,
        filename: 'selfie.mp4',
      ),
    });

    final response = await _dio.post<dynamic>('/Kyc/submit', data: fd);
    return _parseSubmitMessage(response.data);
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
