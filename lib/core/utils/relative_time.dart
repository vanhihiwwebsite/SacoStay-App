/// Relative time in Vietnamese — mirror web `formatRelativeTimeVi`.
String formatRelativeTimeVi(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '—';
  final diffMs = DateTime.now().difference(date.toLocal()).inMilliseconds;
  final mins = diffMs ~/ 60000;
  if (mins < 1) return 'Vừa xong';
  if (mins < 60) return '$mins phút trước';
  final hours = mins ~/ 60;
  if (hours < 24) return '$hours giờ trước';
  final days = hours ~/ 24;
  if (days < 7) return '$days ngày trước';
  final weeks = days ~/ 7;
  if (weeks < 5) return '$weeks tuần trước';
  final d = date.toLocal();
  return '${d.day}/${d.month}/${d.year}';
}
