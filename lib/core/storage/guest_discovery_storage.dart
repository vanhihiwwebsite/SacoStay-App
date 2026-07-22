import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lifestyle.dart';

const _sessionKey = 'saco_guest_discovery_v1';

/// Guest discovery session — mirrors web `guest-discovery.storage.ts`.
class GuestDiscoveryStorage {
  GuestDiscoveryStorage(this._prefs);

  final SharedPreferences _prefs;

  static Future<GuestDiscoveryStorage> create() async {
    return GuestDiscoveryStorage(await SharedPreferences.getInstance());
  }

  bool get hasQuizCompleted {
    final session = _readSession();
    _maybeResetWeeklyQuota(session);
    return session.quizCompleted;
  }

  List<int> get selectedOptionIds {
    final session = _readSession();
    _maybeResetWeeklyQuota(session);
    return List<int>.from(session.selectedOptionIds);
  }

  List<UserLifestyleAnswer> get answers {
    final session = _readSession();
    _maybeResetWeeklyQuota(session);
    return session.answers
        .map(
          (a) => UserLifestyleAnswer(
            questionId: a.questionId,
            questionContent: a.questionContent,
            optionId: a.optionId,
            optionContent: a.optionContent,
          ),
        )
        .toList();
  }

  Future<void> saveQuizResult({
    required List<LifestyleQuestion> questions,
    required Map<int, int> answers,
    required List<int> selectedOptionIds,
  }) async {
    final built = <UserLifestyleAnswer>[];
    for (final entry in answers.entries) {
      LifestyleQuestion? question;
      for (final q in questions) {
        if (q.id == entry.key) {
          question = q;
          break;
        }
      }
      if (question == null) continue;
      LifestyleOption? option;
      for (final o in question.options) {
        if (o.id == entry.value) {
          option = o;
          break;
        }
      }
      if (option == null) continue;
      built.add(
        UserLifestyleAnswer(
          questionId: question.id,
          questionContent: question.content,
          optionId: option.id,
          optionContent: option.content,
        ),
      );
    }
    built.sort((a, b) => a.questionId.compareTo(b.questionId));

    final session = _readSession();
    session.quizCompleted = true;
    session.selectedOptionIds = selectedOptionIds;
    session.answers = built
        .map(
          (a) => _GuestAnswer(
            questionId: a.questionId,
            questionContent: a.questionContent,
            optionId: a.optionId,
            optionContent: a.optionContent,
          ),
        )
        .toList();
    await _writeSession(session);
  }

  Future<void> clear() async {
    await _prefs.remove(_sessionKey);
  }

  _GuestSession _readSession() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return _GuestSession.empty();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _GuestSession.fromJson(map);
    } catch (_) {
      return _GuestSession.empty();
    }
  }

  Future<void> _writeSession(_GuestSession session) async {
    await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  void _maybeResetWeeklyQuota(_GuestSession session) {
    final resetAt = DateTime.tryParse(session.weekResetAt);
    if (resetAt == null || DateTime.now().isBefore(resetAt)) return;
    session.usedSwipesThisWeek = 0;
    session.weekResetAt = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    _writeSession(session);
  }
}

class _GuestSession {
  _GuestSession({
    required this.quizCompleted,
    required this.selectedOptionIds,
    required this.answers,
    required this.usedSwipesThisWeek,
    required this.weekResetAt,
  });

  bool quizCompleted;
  List<int> selectedOptionIds;
  List<_GuestAnswer> answers;
  int usedSwipesThisWeek;
  String weekResetAt;

  factory _GuestSession.empty() => _GuestSession(
        quizCompleted: false,
        selectedOptionIds: [],
        answers: [],
        usedSwipesThisWeek: 0,
        weekResetAt: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      );

  factory _GuestSession.fromJson(Map<String, dynamic> json) {
    final answersRaw = json['answers'];
    return _GuestSession(
      quizCompleted: json['quizCompleted'] == true,
      selectedOptionIds: (json['selectedOptionIds'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse('$e') ?? 0)
          .where((id) => id > 0)
          .toList(),
      answers: answersRaw is List
          ? answersRaw
              .whereType<Map>()
              .map((e) => _GuestAnswer.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      usedSwipesThisWeek: int.tryParse('${json['usedSwipesThisWeek']}') ?? 0,
      weekResetAt: '${json['weekResetAt'] ?? ''}'.isNotEmpty
          ? '${json['weekResetAt']}'
          : DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'quizCompleted': quizCompleted,
        'selectedOptionIds': selectedOptionIds,
        'answers': answers.map((a) => a.toJson()).toList(),
        'usedSwipesThisWeek': usedSwipesThisWeek,
        'weekResetAt': weekResetAt,
      };
}

class _GuestAnswer {
  const _GuestAnswer({
    required this.questionId,
    required this.questionContent,
    required this.optionId,
    required this.optionContent,
  });

  final int questionId;
  final String questionContent;
  final int optionId;
  final String optionContent;

  factory _GuestAnswer.fromJson(Map<String, dynamic> json) => _GuestAnswer(
        questionId: int.tryParse('${json['questionId']}') ?? 0,
        questionContent: '${json['questionContent'] ?? ''}',
        optionId: int.tryParse('${json['optionId']}') ?? 0,
        optionContent: '${json['optionContent'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'questionContent': questionContent,
        'optionId': optionId,
        'optionContent': optionContent,
      };
}
