import '../../config/environment.dart';

/// Mirror `utils/media-url.ts`.
String resolveMediaUrl(String? path, {String? apiUrl}) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  final base = (apiUrl ?? Environment.apiUrl).replaceAll(RegExp(r'/api/?$'), '');
  return path.startsWith('/') ? '$base$path' : '$base/$path';
}

String avatarFallbackUrl(String name) {
  final encoded = Uri.encodeComponent(name.isEmpty ? 'User' : name);
  return 'https://ui-avatars.com/api/?name=$encoded&background=FF9F43&color=fff';
}
