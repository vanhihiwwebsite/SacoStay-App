import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../features/auth/auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider).dio);
});

final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isLoggedIn) return 0;
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});

class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get<dynamic>('/Notification/unread-count');
      final raw = response.data;
      if (raw is num) return raw.round();
      if (raw is Map) {
        final o = Map<String, dynamic>.from(raw);
        return num.tryParse(
              strField(
                pickField(o, 'unreadCount', ['UnreadCount', 'count', 'Count']),
              ),
            )?.round() ??
            0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
