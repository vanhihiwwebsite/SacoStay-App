import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../core/utils/user_display.dart';
import '../features/auth/auth_provider.dart';
import '../models/chat.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider).dio);
});

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<List<ChatConversationSummary>> getConversations() async {
    try {
      final response = await _dio.get<dynamic>('/Chat/conversations');
      return _normalizeConversations(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<ChatMessage>> getHistory(
    String otherUserId,
    String currentUserId,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Chat/history/${Uri.encodeComponent(otherUserId)}',
      );
      return _normalizeMessages(response.data, currentUserId);
    } catch (_) {
      return [];
    }
  }

  Future<ChatParticipant> fetchPeer(String userId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Auth/user/${Uri.encodeComponent(userId)}',
      );
      if (response.data is Map) {
        final o = Map<String, dynamic>.from(response.data as Map);
        final name = navProfileLabel(o);
        final roles = listOfStrings(o['roles'] ?? o['Roles']);
        return ChatParticipant(
          id: userId,
          displayName: name,
          avatarUrl: resolveUserAvatarUrl(o, displayName: name),
          roles: roles,
        );
      }
    } catch (_) {}
    return ChatParticipant(id: userId, displayName: 'Người dùng');
  }

  List<ChatConversationSummary> _normalizeConversations(dynamic raw) {
    final list = _unwrapList(raw);
    final result = <ChatConversationSummary>[];
    for (final item in list) {
      if (item is! Map) continue;
      final o = Map<String, dynamic>.from(item);
      final id = strField(
        pickField(o, 'otherUserId', ['OtherUserId', 'userId', 'UserId']),
      );
      if (id.isEmpty) continue;
      result.add(
        ChatConversationSummary(
          otherUserId: id,
          lastMessageText: strField(
            pickField(
              o,
              'lastMessage',
              ['LastMessage', 'message', 'Message', 'text', 'Text'],
            ),
          ),
          lastMessageAt: strField(
            pickField(o, 'lastSentAt', ['LastSentAt', 'sentAt', 'SentAt']),
          ),
        ),
      );
    }
    return result;
  }

  List<ChatMessage> _normalizeMessages(dynamic raw, String currentUserId) {
    final me = currentUserId.toLowerCase();
    final list = _unwrapList(raw);
    final result = <ChatMessage>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final o = Map<String, dynamic>.from(item);
      final senderId = strField(
        pickField(
          o,
          'senderId',
          ['SenderId', 'fromUserId', 'FromUserId', 'userId', 'UserId'],
        ),
      );
      final text = strField(
        pickField(o, 'message', ['Message', 'text', 'Text', 'content', 'Content']),
      );
      if (text.isEmpty) continue;
      final sid = senderId.isNotEmpty ? senderId : currentUserId;
      final sentAt = strField(
        pickField(o, 'sentAt', ['SentAt', 'createdAt', 'CreatedAt']),
      );
      result.add(
        ChatMessage(
          id: strField(pickField(o, 'id', ['Id'])).isNotEmpty
              ? strField(pickField(o, 'id', ['Id']))
              : 'msg-$i',
          senderId: sid,
          text: text,
          sentAt: sentAt.isNotEmpty ? sentAt : null,
          isMine: sid.toLowerCase() == me,
        ),
      );
    }
    return result;
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    final nested = pickField(
      map,
      'data',
      ['items', 'result', 'messages', 'history'],
    );
    if (nested is List) return nested;
    return [];
  }
}
