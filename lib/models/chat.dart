class ChatConversationSummary {
  const ChatConversationSummary({
    required this.otherUserId,
    this.lastMessageText,
    this.lastMessageAt,
  });

  final String otherUserId;
  final String? lastMessageText;
  final String? lastMessageAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
    required this.isMine,
  });

  final String id;
  final String senderId;
  final String text;
  final String? sentAt;
  final bool isMine;
}

class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.roles = const [],
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final List<String> roles;

  bool get isLandlord =>
      roles.any((r) => r.toLowerCase().contains('landlord'));
}
