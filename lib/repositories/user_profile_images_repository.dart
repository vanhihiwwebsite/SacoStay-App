import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../core/utils/media_url.dart';
import '../core/utils/user_display.dart';
import '../features/auth/auth_provider.dart';

final userProfileImagesRepositoryProvider =
    Provider<UserProfileImagesRepository>((ref) {
  return UserProfileImagesRepository(ref.watch(apiClientProvider).dio);
});

class UserProfileImagesRepository {
  UserProfileImagesRepository(this._dio);

  final Dio _dio;

  static const maxPhotos = 5;

  Future<List<String>> getMyImages() async {
    try {
      final response = await _dio.get<dynamic>('/User/profile-images');
      return profileImageUrlsFromApiList(response.data)
          .where((u) => !u.toLowerCase().contains('avatars'))
          .map(resolveMediaUrl)
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> upload(List<String> filePaths) async {
    final fd = FormData();
    for (final path in filePaths) {
      fd.files.add(
        MapEntry(
          'Files',
          await MultipartFile.fromFile(path, filename: 'photo.jpg'),
        ),
      );
    }
    final response = await _dio.post<dynamic>('/User/profile-images', data: fd);
    return profileImageUrlsFromApiList(response.data).map(resolveMediaUrl).toList();
  }

  Future<void> delete(String imageUrl) async {
    await _dio.delete<void>(
      '/User/profile-images',
      queryParameters: {'imageUrl': imageUrl},
    );
  }
}
