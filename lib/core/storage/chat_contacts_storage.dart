import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredChatContact {
  const StoredChatContact({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.role,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? role;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (role != null) 'role': role,
      };

  factory StoredChatContact.fromJson(Map<String, dynamic> json) {
    return StoredChatContact(
      id: '${json['id'] ?? ''}',
      displayName: '${json['displayName'] ?? 'Người dùng'}',
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String?,
    );
  }
}

class ChatContactsStorage {
  static String _key(String ownerUserId) => 'saco_chat_contacts_$ownerUserId';

  static Future<List<StoredChatContact>> load(String ownerUserId) async {
    if (ownerUserId.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(ownerUserId));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(StoredChatContact.fromJson)
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsert(String ownerUserId, StoredChatContact contact) async {
    if (ownerUserId.isEmpty || contact.id.isEmpty) return;
    final list = await load(ownerUserId);
    final next = [
      contact,
      ...list.where((c) => c.id.toLowerCase() != contact.id.toLowerCase()),
    ].take(50).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(ownerUserId),
      jsonEncode(next.map((c) => c.toJson()).toList()),
    );
  }
}
