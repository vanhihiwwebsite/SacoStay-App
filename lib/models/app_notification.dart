class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.isRead = false,
    this.createdAt,
    this.type,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final String? type;
}
