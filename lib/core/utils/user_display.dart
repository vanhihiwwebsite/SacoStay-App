import 'json_normalize.dart';

String displayNameFromUser(Map<String, dynamic>? user) {
  if (user == null) return 'Người dùng';
  final un = strField(pickField(user, 'userName', ['UserName', 'username']));
  if (un.isNotEmpty) return un;
  final em = strField(pickField(user, 'email', ['Email']));
  if (em.isNotEmpty) {
    final local = em.split('@').first;
    if (local.isNotEmpty) return local;
  }
  final ph = strField(pickField(user, 'phoneNumber', ['PhoneNumber']));
  if (ph.isNotEmpty) return ph;
  return 'Người dùng';
}

String navProfileLabel(Map<String, dynamic>? user) {
  if (user == null) return 'Người dùng';
  final fn = strField(pickField(user, 'firstName', ['FirstName']));
  final ln = strField(pickField(user, 'lastName', ['LastName']));
  final full = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
  if (full.isNotEmpty) return full;
  return displayNameFromUser(user);
}

Map<String, dynamic> normalizeAuthUser(Map<String, dynamic> raw) {
  final base = unwrapData(Map<String, dynamic>.from(raw));
  final o = Map<String, dynamic>.from(base);

  void copyScalar(String camel, List<String> keys) {
    if (strField(o[camel]).isNotEmpty) return;
    for (final key in keys) {
      final v = o[key];
      if (v == null) continue;
      final s = strField(v);
      if (s.isEmpty) continue;
      o[camel] = v;
      return;
    }
  }

  copyScalar('firstName', ['FirstName', 'first_name']);
  copyScalar('lastName', ['LastName', 'last_name']);
  copyScalar('phoneNumber', ['PhoneNumber', 'phone_number', 'Phone']);
  copyScalar('email', ['Email']);
  copyScalar('userName', ['UserName', 'username', 'user_name']);
  copyScalar('id', ['Id', 'ID']);
  copyScalar('avatar', ['Avatar', 'AvatarUrl', 'avatarUrl']);

  if (o['roles'] == null && o['Roles'] is List) {
    o['roles'] = o['Roles'];
  }

  return o;
}

String? userIdFromUser(Map<String, dynamic>? user) {
  if (user == null) return null;
  final id = strField(pickField(user, 'id', ['Id', 'ID']));
  return id.isEmpty ? null : id;
}

bool isAdminUser(Map<String, dynamic>? user) {
  final roles = listOfStrings(user?['roles'] ?? user?['Roles']);
  return roles.any((r) => r.toLowerCase().contains('admin'));
}

bool isLandlordUser(Map<String, dynamic>? user) {
  final roles = listOfStrings(user?['roles'] ?? user?['Roles']);
  return roles.any((r) => r.toLowerCase().contains('landlord'));
}

String resolveUserRole(Map<String, dynamic>? user, {String? pendingRole}) {
  if (isAdminUser(user)) return 'admin';
  final roles = listOfStrings(user?['roles'] ?? user?['Roles']);
  if (roles.isNotEmpty) {
    final lower = roles.map((r) => r.toLowerCase()).toList();
    if (lower.any((r) => r.contains('landlord'))) return 'landlord';
    return 'tenant';
  }
  return pendingRole ?? 'tenant';
}

String? profileAvatarFromRaw(Map<String, dynamic>? user) {
  if (user == null) return null;
  final avatar = strField(pickField(user, 'avatar', ['Avatar', 'AvatarUrl', 'avatarUrl']));
  return avatar.isEmpty ? null : avatar;
}

bool hasBasicProfileFilled(Map<String, dynamic>? user) {
  if (user == null) return false;
  final fn = strField(pickField(user, 'firstName', ['FirstName']));
  final ln = strField(pickField(user, 'lastName', ['LastName']));
  return fn.isNotEmpty && ln.isNotEmpty;
}
