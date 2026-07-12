import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../core/utils/media_url.dart';
import '../features/auth/auth_provider.dart';
import '../models/tenant_room_profile.dart';

final tenantRoomRepositoryProvider = Provider<TenantRoomRepository>((ref) {
  return TenantRoomRepository(ref.watch(apiClientProvider).dio);
});

class TenantRoomSaveResult {
  const TenantRoomSaveResult({required this.message, this.profile});

  final String message;
  final TenantRoomProfile? profile;
}

class TenantRoomRepository {
  TenantRoomRepository(this._dio);

  final Dio _dio;

  Future<TenantRoomProfile?> getByUserId(String userId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/TenantRoomProfile/${Uri.encodeComponent(userId)}',
      );
      return _normalize(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<TenantRoomProfile?> getMyProfile() async {
    try {
      final response = await _dio.get<dynamic>('/TenantRoomProfile/me');
      return _normalize(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<TenantRoomSaveResult> create(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>('/TenantRoomProfile', data: payload);
    return _saveResult(response.data, 'Tạo thông tin phòng thành công!');
  }

  Future<TenantRoomSaveResult> update(Map<String, dynamic> payload) async {
    final response = await _dio.put<dynamic>('/TenantRoomProfile', data: payload);
    return _saveResult(response.data, 'Cập nhật thông tin phòng thành công!');
  }

  Future<TenantRoomSaveResult> uploadImages(List<String> filePaths) async {
    final fd = FormData();
    for (final path in filePaths) {
      fd.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(path, filename: 'room.jpg'),
        ),
      );
    }
    final response = await _dio.post<dynamic>('/TenantRoomProfile/images', data: fd);
    return _saveResult(response.data, 'Upload ảnh thành công!');
  }

  Future<TenantRoomSaveResult> deleteImage(String imageUrl) async {
    final response = await _dio.delete<dynamic>(
      '/TenantRoomProfile/images',
      queryParameters: {'imageUrl': imageUrl},
    );
    return _saveResult(response.data, 'Xóa ảnh thành công!');
  }

  Future<TenantRoomSaveResult> save({
    required Map<String, dynamic> payload,
    List<String> imagePaths = const [],
  }) async {
    final existing = await getMyProfile();
    final result = existing != null ? await update(payload) : await create(payload);
    if (imagePaths.isEmpty) return result;
    final uploaded = await uploadImages(imagePaths);
    return TenantRoomSaveResult(
      message: uploaded.message.isNotEmpty ? uploaded.message : result.message,
      profile: uploaded.profile ?? result.profile,
    );
  }

  TenantRoomSaveResult _saveResult(dynamic raw, String fallback) {
    var message = fallback;
    TenantRoomProfile? profile;
    if (raw is Map) {
      final o = Map<String, dynamic>.from(raw);
      final msg = strField(pickField(o, 'message', ['Message']));
      if (msg.isNotEmpty) message = msg;
      final data = pickField(o, 'data', ['Data']);
      profile = _normalize(data ?? o);
    }
    return TenantRoomSaveResult(message: message, profile: profile);
  }

  TenantRoomProfile? _normalize(dynamic raw) {
    if (raw is! Map) return null;
    var o = Map<String, dynamic>.from(raw);
    final nested = o['data'] ?? o['Data'];
    if (nested is Map) o = Map<String, dynamic>.from(nested);

    final amenitiesRaw = pickField(o, 'amenities', ['Amenities']);
    final amenities = amenitiesRaw is List
        ? amenitiesRaw.map((e) => strField(e)).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final imagesRaw = pickField(o, 'images', ['Images']);
    final images = imagesRaw is List
        ? imagesRaw
            .map((e) => resolveMediaUrl(strField(e)))
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final price = num.tryParse(strField(pickField(o, 'price', ['Price'])));

    return TenantRoomProfile(
      userId: strField(pickField(o, 'userId', ['UserId'])),
      city: strField(pickField(o, 'city', ['City'])).isEmpty
          ? null
          : strField(pickField(o, 'city', ['City'])),
      district: strField(pickField(o, 'district', ['District'])).isEmpty
          ? null
          : strField(pickField(o, 'district', ['District'])),
      maxPeople: num.tryParse(
        strField(pickField(o, 'maxPeople', ['MaxPeople'])),
      )?.round(),
      price: price != null && price > 0 ? price.round() : null,
      amenities: amenities,
      extraNotes: strField(pickField(o, 'extraNotes', ['ExtraNotes'])).isEmpty
          ? null
          : strField(pickField(o, 'extraNotes', ['ExtraNotes'])),
      images: images,
    );
  }
}
