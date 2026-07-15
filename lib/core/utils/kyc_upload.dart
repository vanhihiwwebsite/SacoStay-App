import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

/// Giới hạn giống web — FPT.AI OCR cần JPG/PNG rõ nét.
const kMaxKycImageBytes = 5 * 1024 * 1024;

/// Video quá nhỏ thường là lỗi ghi hoặc file rỗng.
const kMinKycVideoBytes = 10 * 1024;

const _allowedImageExt = {'jpg', 'jpeg', 'png'};

String? validateKycIdImagePath(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return 'Không đọc được file ảnh. Vui lòng chọn lại.';
  }

  final ext = _extension(path);
  if (!_allowedImageExt.contains(ext)) {
    return 'Chỉ chấp nhận ảnh JPG hoặc PNG. Ảnh HEIC/WebP có thể khiến FPT.AI không đọc được CCCD.';
  }

  final size = file.lengthSync();
  if (size > kMaxKycImageBytes) {
    return 'Ảnh tối đa 5MB.';
  }
  if (size == 0) {
    return 'File ảnh rỗng. Vui lòng chọn lại.';
  }
  return null;
}

String? validateKycVideoPath(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return 'Không đọc được file video. Vui lòng quay lại.';
  }

  final size = file.lengthSync();
  if (size < kMinKycVideoBytes) {
    return 'Video quá ngắn hoặc lỗi. Vui lòng quay lại.';
  }
  return null;
}

Future<MultipartFile> kycImageMultipart(String path, String baseName) async {
  final ext = _extension(path);
  final mime = ext == 'png'
      ? MediaType('image', 'png')
      : MediaType('image', 'jpeg');
  final filename = ext == 'png' ? '$baseName.png' : '$baseName.jpg';

  return MultipartFile.fromFile(
    path,
    filename: filename,
    contentType: mime,
  );
}

Future<MultipartFile> kycVideoMultipart(String path) async {
  final ext = _extension(path);
  final isMp4 = ext == 'mp4' || ext == 'mov';
  final mime = isMp4 ? MediaType('video', 'mp4') : MediaType('video', 'webm');
  final filename = isMp4 ? 'selfie.mp4' : 'selfie.webm';

  return MultipartFile.fromFile(
    path,
    filename: filename,
    contentType: mime,
  );
}

String kycImageDisplayName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash < 0 || slash >= normalized.length - 1) return path;
  return normalized.substring(slash + 1);
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot >= path.length - 1) return '';
  return path.substring(dot + 1).toLowerCase();
}
