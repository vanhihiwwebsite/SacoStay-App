import 'package:shared_preferences/shared_preferences.dart';

const userCacheKey = 'saco_stay_user';
const sessionPendingRoleKey = 'saco_pending_user_role';
const sessionAuthReturnUrlKey = 'saco_auth_return_url';

const tempEmailKey = 'temp_email';
const tempPasswordKey = 'temp_password';
const tempUserNameKey = 'temp_userName';
const tempFirstNameKey = 'temp_firstName';
const tempLastNameKey = 'temp_lastName';
const tempPhoneKey = 'temp_phone';
const tempNameKey = 'temp_name';
const resetEmailKey = 'reset_email';

class UserPrefs {
  UserPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<UserPrefs> create() async {
    final prefs = await SharedPreferences.getInstance();
    return UserPrefs(prefs);
  }

  String? get cachedUserJson => _prefs.getString(userCacheKey);

  Future<void> setCachedUserJson(String json) =>
      _prefs.setString(userCacheKey, json);

  Future<void> clearCachedUser() => _prefs.remove(userCacheKey);

  String? get pendingRole => _prefs.getString(sessionPendingRoleKey);

  Future<void> setPendingRole(String role) =>
      _prefs.setString(sessionPendingRoleKey, role);

  Future<void> clearPendingRole() => _prefs.remove(sessionPendingRoleKey);

  String? get authReturnUrl => _prefs.getString(sessionAuthReturnUrlKey);

  Future<void> setAuthReturnUrl(String url) =>
      _prefs.setString(sessionAuthReturnUrlKey, url);

  Future<void> clearAuthReturnUrl() => _prefs.remove(sessionAuthReturnUrlKey);

  Future<void> saveTempRegister({
    required String email,
    required String password,
    required String userName,
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
  }) async {
    await _prefs.setString(tempEmailKey, email);
    await _prefs.setString(tempPasswordKey, password);
    await _prefs.setString(tempUserNameKey, userName);
    await _prefs.setString(tempFirstNameKey, firstName);
    await _prefs.setString(tempLastNameKey, lastName);
    await _prefs.setString(tempPhoneKey, phone);
    await _prefs.setString(tempNameKey, '$firstName $lastName'.trim());
    await setPendingRole(role);
  }

  String? get tempEmail => _prefs.getString(tempEmailKey);
  String? get tempPassword => _prefs.getString(tempPasswordKey);
  String? get tempFirstName => _prefs.getString(tempFirstNameKey);
  String? get tempLastName => _prefs.getString(tempLastNameKey);
  String? get tempPhone => _prefs.getString(tempPhoneKey);

  String? get resetEmail => _prefs.getString(resetEmailKey);

  Future<void> setResetEmail(String email) =>
      _prefs.setString(resetEmailKey, email);

  Future<void> clearResetEmail() => _prefs.remove(resetEmailKey);

  Future<void> clearTempRegister() async {
    await _prefs.remove(tempEmailKey);
    await _prefs.remove(tempPasswordKey);
    await _prefs.remove(tempUserNameKey);
    await _prefs.remove(tempFirstNameKey);
    await _prefs.remove(tempLastNameKey);
    await _prefs.remove(tempPhoneKey);
    await _prefs.remove(tempNameKey);
  }

  Future<void> clearSessionKeys() async {
    await clearCachedUser();
    await clearPendingRole();
    await clearAuthReturnUrl();
    await clearTempRegister();
    await clearResetEmail();
    final keys = _prefs.getKeys().where((k) =>
        k.startsWith('saco_') || k.startsWith('temp_') || k == 'user');
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
