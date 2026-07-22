import 'package:shared_preferences/shared_preferences.dart';

/// Local flag after POST /Lifestyle/submit — mirrors web `lifestyle-storage.ts`.
class LifestyleStorage {
  LifestyleStorage(this._prefs);

  final SharedPreferences _prefs;

  static Future<LifestyleStorage> create() async {
    return LifestyleStorage(await SharedPreferences.getInstance());
  }

  String _doneKey(String userId) => 'saco_lifestyle_completed_$userId';

  bool hasCompletedQuiz(String userId) {
    if (userId.isEmpty) return false;
    return _prefs.getString(_doneKey(userId)) == '1';
  }

  Future<void> setQuizCompleted(String userId) async {
    if (userId.isEmpty) return;
    await _prefs.setString(_doneKey(userId), '1');
  }

  Future<void> clearQuizCompleted(String userId) async {
    if (userId.isEmpty) return;
    await _prefs.remove(_doneKey(userId));
  }
}
