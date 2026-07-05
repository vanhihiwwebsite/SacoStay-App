import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../core/utils/presence.dart';
import '../features/auth/auth_provider.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository(ref.watch(apiClientProvider).dio);
});

class UserPresence {
  const UserPresence({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });

  final String userId;
  final bool isOnline;
  final String? lastSeenAt;
}

class PresenceRepository {
  PresenceRepository(this._dio);

  final Dio _dio;

  Future<List<UserPresence>> fetchPresence(List<String> userIds) async {
    final ids = userIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return [];

    try {
      final response = await _dio.post<dynamic>(
        '/Activity/presence',
        data: {'userIds': ids},
      );
      return _normalizeBatch(response.data, ids);
    } catch (_) {
      return _fetchFallback(ids);
    }
  }

  List<UserPresence> _normalizeBatch(dynamic raw, List<String> requestedIds) {
    final list = _unwrapList(raw);
    final byId = <String, UserPresence>{};
    for (final item in list) {
      if (item is! Map) continue;
      final p = _normalizeOne(Map<String, dynamic>.from(item));
      if (p.userId.isNotEmpty) {
        byId[p.userId.toLowerCase()] = p;
      }
    }
    return requestedIds.map((id) {
      return byId[id.toLowerCase()] ?? UserPresence(userId: id, isOnline: false);
    }).toList();
  }

  UserPresence _normalizeOne(Map<String, dynamic> o) {
    final userId = strField(
      pickField(o, 'userId', ['UserId', 'id', 'Id']),
    );
    final lastSeenAt = strField(
      pickField(o, 'lastSeenAt', ['LastSeenAt']),
    );
    final isOnlineRaw = o['isOnline'] ?? o['IsOnline'];
    final isOnline = isOnlineRaw is bool
        ? isOnlineRaw
        : isOnlineFromLastSeen(lastSeenAt.isNotEmpty ? lastSeenAt : null);
    return UserPresence(
      userId: userId,
      isOnline: isOnline,
      lastSeenAt: lastSeenAt.isNotEmpty ? lastSeenAt : null,
    );
  }

  Future<List<UserPresence>> _fetchFallback(List<String> ids) async {
    final results = <UserPresence>[];
    for (final id in ids) {
      try {
        final response = await _dio.get<dynamic>('/Auth/user/${Uri.encodeComponent(id)}');
        if (response.data is Map) {
          results.add(_normalizeOne(Map<String, dynamic>.from(response.data as Map)));
        } else {
          results.add(UserPresence(userId: id, isOnline: false));
        }
      } catch (_) {
        results.add(UserPresence(userId: id, isOnline: false));
      }
    }
    return results;
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    final nested = pickField(map, 'items', ['Items', '\$values', 'data', 'Data']);
    if (nested is List) return nested;
    return [];
  }
}
