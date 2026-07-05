/// Online if lastSeenAt within 2 minutes (matches web + guide).
const onlineThresholdMs = 2 * 60 * 1000;

bool isOnlineFromLastSeen(String? lastSeenAt, [int? nowMs]) {
  if (lastSeenAt == null || lastSeenAt.isEmpty) return false;
  final t = DateTime.tryParse(lastSeenAt);
  if (t == null) return false;
  return (nowMs ?? DateTime.now().millisecondsSinceEpoch) - t.millisecondsSinceEpoch <=
      onlineThresholdMs;
}

String presenceLabel({required bool isOnline, String? lastSeenAt}) {
  if (isOnline) return 'Đang hoạt động';
  if (lastSeenAt == null || lastSeenAt.isEmpty) return 'Offline';
  final t = DateTime.tryParse(lastSeenAt);
  if (t == null) return 'Offline';
  final diffMin = DateTime.now().difference(t.toLocal()).inMinutes;
  if (diffMin < 1) return 'Offline · vừa xong';
  if (diffMin < 60) return 'Offline · $diffMin phút trước';
  final diffH = diffMin ~/ 60;
  if (diffH < 24) return 'Offline · $diffH giờ trước';
  return 'Offline · ${t.toLocal().day}/${t.toLocal().month}/${t.toLocal().year}';
}
