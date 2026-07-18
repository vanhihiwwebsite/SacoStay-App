import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../core/api/api_exception.dart';
import '../features/auth/auth_provider.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(apiClientProvider).dio);
});

const kMaxReportImages = 3;
const kMaxReportImageBytes = 5 * 1024 * 1024;

const roomReportReasons = [
  'Nhà không đúng trong hình',
  'Giá không minh bạch',
  'Thông tin sai lệch',
  'Địa chỉ không chính xác',
  'Lừa đảo / Scam',
  'Nội dung không phù hợp',
];

const userReportReasons = [
  'Hồ sơ giả mạo',
  'Hành vi quấy rối',
  'Thông tin sai lệch',
  'Lừa đảo / Scam',
  'Nội dung không phù hợp',
  'Spam / Quảng cáo',
];

class ReportRepository {
  ReportRepository(this._dio);

  final Dio _dio;

  Future<String> submit({
    required String reporterId,
    required List<String> reasons,
    required String description,
    String? reportedUserId,
    String? reportedRoomId,
    List<String> imagePaths = const [],
  }) async {
    if (reasons.isEmpty) {
      throw ApiException(message: 'Vui lòng chọn ít nhất một lý do.');
    }

    final fd = FormData();
    fd.fields.add(MapEntry('ReporterId', reporterId));
    if (reportedUserId != null && reportedUserId.isNotEmpty) {
      fd.fields.add(MapEntry('ReportedUserId', reportedUserId));
    }
    if (reportedRoomId != null && reportedRoomId.isNotEmpty) {
      fd.fields.add(MapEntry('ReportedRoomId', reportedRoomId));
    }
    fd.fields.add(MapEntry('Reason', reasons.join('; ')));
    fd.fields.add(MapEntry('Description', description.trim()));

    for (final path in imagePaths) {
      fd.files.add(MapEntry('Images', await _imageMultipart(path)));
    }

    try {
      final response = await _dio.post<dynamic>('/Report', data: fd);
      return _parseMessage(response.data);
    } on DioException catch (e) {
      throw ApiException(
        message: extractDioErrorMessage(e) ??
            'Gửi báo cáo thất bại. Vui lòng thử lại.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<MultipartFile> _imageMultipart(String path) async {
    final ext = path.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');
    final safeName = path.split(Platform.pathSeparator).last;
    return MultipartFile.fromFile(
      path,
      filename: safeName,
      contentType: mime,
    );
  }

  String _parseMessage(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return 'Gửi báo cáo thành công.';
      if (!trimmed.startsWith('{')) return trimmed;
    }
    if (raw is Map) {
      final msg = (raw['message'] ?? raw['Message'] ?? '').toString().trim();
      if (msg.isNotEmpty) return msg;
    }
    return 'Gửi báo cáo thành công.';
  }
}

String? validateReportImagePath(String path) {
  final file = File(path);
  if (!file.existsSync()) return 'Không đọc được file ảnh.';
  final ext = path.split('.').last.toLowerCase();
  if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
    return 'Chỉ chấp nhận ảnh JPG hoặc PNG.';
  }
  if (file.lengthSync() > kMaxReportImageBytes) {
    return 'Ảnh phải nhỏ hơn 5MB.';
  }
  return null;
}
