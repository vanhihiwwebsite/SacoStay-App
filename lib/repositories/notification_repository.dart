import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../features/auth/auth_provider.dart';
import '../models/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider).dio);
});

final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isLoggedIn) return 0;
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});

final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isLoggedIn) return [];
  return ref.watch(notificationRepositoryProvider).listNotifications();
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

  Future<List<AppNotification>> listNotifications({
    int page = 1,
    int pageSize = 30,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Notification',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return _normalizeList(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.patch('/Notification/${Uri.encodeComponent(id)}/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch('/Notification/read-all');
    } catch (_) {}
  }

  List<AppNotification> _normalizeList(dynamic raw) {
    final items = _unwrapList(raw);
    final result = <AppNotification>[];
    for (var i = 0; i < items.length; i++) {
      final n = _normalizeItem(items[i], i);
      if (n != null) result.add(n);
    }
    return result;
  }

  AppNotification? _normalizeItem(dynamic item, int index) {
    if (item is! Map) return null;
    final o = Map<String, dynamic>.from(item);
    final id = strField(pickField(o, 'id', ['Id', 'notificationId', 'NotificationId']));
    final title = strField(pickField(o, 'title', ['Title', 'subject', 'Subject']));
    final body = strField(
      pickField(o, 'body', ['Body', 'message', 'Message', 'content', 'Content']),
    );
    final isRead = pickField(o, 'isRead', ['IsRead', 'read', 'Read']) == true;
    final createdRaw = strField(
      pickField(o, 'createdAt', ['CreatedAt', 'sentAt', 'SentAt']),
    );
    DateTime? createdAt;
    if (createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }
    return AppNotification(
      id: id.isNotEmpty ? id : 'notif-$index',
      title: title.isNotEmpty ? title : 'Thông báo',
      body: body,
      isRead: isRead,
      createdAt: createdAt,
      type: strField(pickField(o, 'type', ['Type', 'category', 'Category'])).isNotEmpty
          ? strField(pickField(o, 'type', ['Type', 'category', 'Category']))
          : null,
    );
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    final nested = pickField(
      map,
      'data',
      ['items', 'notifications', 'Notifications', 'result', 'value', r'$values'],
    );
    if (nested is List) return nested;
    return [];
  }
}
