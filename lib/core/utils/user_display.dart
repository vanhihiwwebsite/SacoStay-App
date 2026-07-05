import 'media_url.dart';
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
  final raw = pickField(user, 'avatar', ['Avatar', 'AvatarUrl', 'avatarUrl']);
  if (raw is List) {
    for (final item in raw) {
      final url = item is String
          ? strField(item)
          : item is Map
              ? strField(pickField(Map<String, dynamic>.from(item), 'url', ['Url']))
              : '';
      if (url.isNotEmpty && !url.startsWith('[')) return url;
    }
  } else {
    final direct = strField(raw);
    if (direct.isNotEmpty && direct.startsWith('http') && !direct.startsWith('[')) {
      return direct;
    }
  }

  final all = profileImagesListFromRaw(user);
  for (final url in all) {
    if (_isAvatarMediaUrl(url)) return url;
  }

  final personal = personalProfileImagesListFromRaw(user);
  if (personal.isEmpty && all.isNotEmpty) return all.first;
  return null;
}

/// URL hiển thị avatar — ưu tiên avatar, sau đó ảnh cá nhân đầu tiên.
String resolveUserAvatarUrl(Map<String, dynamic>? user, {String? displayName}) {
  final label = displayName ?? navProfileLabel(user);
  final fromAvatar = profileAvatarFromRaw(user);
  if (fromAvatar != null && fromAvatar.isNotEmpty) {
    return resolveMediaUrl(fromAvatar);
  }
  final personal = personalProfileImagesListFromRaw(user);
  if (personal.isNotEmpty) return resolveMediaUrl(personal.first);
  return avatarFallbackUrl(label);
}

List<String> profileImageUrlsFromApiList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) {
          if (item is String) return strField(item);
          if (item is Map) {
            final o = Map<String, dynamic>.from(item);
            return strField(pickField(o, 'url', ['Url', 'imageUrl', 'ImageUrl']));
          }
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is! Map) return [];
  final o = Map<String, dynamic>.from(raw);
  final nested = pickField(o, 'images', ['Images', 'data', 'Data']);
  if (nested != null) return profileImageUrlsFromApiList(nested);
  return [];
}

List<String> profileImagesListFromRaw(Map<String, dynamic>? user) {
  if (user == null) return [];
  final raw = pickField(
    user,
    'profileImages',
    ['ProfileImages', 'profileImage', 'ProfileImage'],
  );
  if (raw is List) {
    return profileImageUrlsFromApiList(raw);
  }
  if (raw is String && raw.isNotEmpty) return [raw];
  return [];
}

List<String> personalProfileImagesListFromRaw(Map<String, dynamic>? user) {
  final all = profileImagesListFromRaw(user)
      .map((u) => resolveMediaUrl(u))
      .where((s) => s.isNotEmpty)
      .toList();
  final personal = all.where((u) => _isPersonalProfileMediaUrl(u)).toList();
  if (personal.isNotEmpty) return personal;
  return [];
}

bool _isAvatarMediaUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('/users/avatars/') ||
      lower.contains('users/avatars') ||
      lower.contains('users%2favatars') ||
      lower.contains('/avatars/') ||
      lower.contains('avatar');
}

bool _isPersonalProfileMediaUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('/users/profile/') ||
      lower.contains('/users/profiles/') ||
      lower.contains('users/profile') ||
      lower.contains('users/profiles') ||
      lower.contains('users%2fprofile') ||
      lower.contains('/profile-images/') ||
      lower.contains('/personal/') ||
      lower.contains('/user-images/');
}

bool hasBasicProfileFilled(Map<String, dynamic>? user) {
  if (user == null) return false;
  final fn = strField(pickField(user, 'firstName', ['FirstName']));
  final ln = strField(pickField(user, 'lastName', ['LastName']));
  return fn.isNotEmpty && ln.isNotEmpty;
}

({String firstName, String lastName}) profileFirstLastSeed(Map<String, dynamic>? user) {
  if (user == null) return (firstName: '', lastName: '');
  return (
    firstName: strField(pickField(user, 'firstName', ['FirstName'])),
    lastName: strField(pickField(user, 'lastName', ['LastName'])),
  );
}

String profileDateOfBirthSeed(Map<String, dynamic>? user) {
  if (user == null) return '';
  final d = strField(pickField(user, 'dateOfBirth', ['DateOfBirth']));
  if (d.isNotEmpty) return d.length >= 10 ? d.substring(0, 10) : d;
  final age = num.tryParse(strField(pickField(user, 'age', ['Age'])));
  if (age != null && age > 0 && age < 120) {
    return '${DateTime.now().year - age.round()}-01-01';
  }
  return '';
}

String profileLivingAreaSeed(Map<String, dynamic>? user) {
  if (user == null) return '';
  return strField(pickField(user, 'livingArea', ['LivingArea']));
}

String genderToFormValue(dynamic g) {
  if (g == true || g == 'male') return 'male';
  if (g == false || g == 'female') return 'female';
  return 'other';
}
