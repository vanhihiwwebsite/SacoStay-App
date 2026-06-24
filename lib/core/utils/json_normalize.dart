/// Read camelCase + PascalCase keys from .NET API responses.
dynamic pickField(Map<String, dynamic> map, String camel, List<String> alternates) {
  if (map.containsKey(camel) && map[camel] != null) return map[camel];
  for (final key in alternates) {
    if (map.containsKey(key) && map[key] != null) return map[key];
  }
  return null;
}

Map<String, dynamic> unwrapData(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
  return json;
}

String strField(dynamic v) {
  if (v == null) return '';
  return v.toString().trim();
}

List<String> listOfStrings(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => strField(e)).where((s) => s.isNotEmpty).toList();
}
