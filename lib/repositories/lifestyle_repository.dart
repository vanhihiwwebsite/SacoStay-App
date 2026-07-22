import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/guest_discovery_storage.dart';
import '../core/storage/lifestyle_storage.dart';
import '../core/utils/json_normalize.dart';
import '../core/api/api_exception.dart';
import '../core/utils/media_url.dart';
import '../core/utils/discovery_filters.dart';
import '../core/utils/lifestyle_display.dart';
import '../core/utils/user_display.dart';
import '../features/auth/auth_provider.dart';
import '../models/lifestyle.dart';
import '../models/tenant_room_profile.dart';
import '../repositories/tenant_room_repository.dart';

final lifestyleStorageProvider = FutureProvider<LifestyleStorage>((ref) {
  return LifestyleStorage.create();
});

final guestDiscoveryStorageProvider = FutureProvider<GuestDiscoveryStorage>((ref) {
  return GuestDiscoveryStorage.create();
});

final lifestyleRepositoryProvider = Provider<LifestyleRepository>((ref) {
  return LifestyleRepository(ref.watch(apiClientProvider).dio);
});

class LifestyleRepository {
  LifestyleRepository(this._dio);

  final Dio _dio;

  Future<List<LifestyleQuestion>> getQuestions() async {
    try {
      final response = await _dio.get<dynamic>('/Lifestyle/questions');
      final items = _unwrapList(response.data);
      if (items.isEmpty) {
        throw ApiException(message: 'Không tải được câu hỏi trắc nghiệm.');
      }
      final questions = <LifestyleQuestion>[];
      for (final item in items) {
        if (item is! Map) continue;
        final o = Map<String, dynamic>.from(item);
        final id = num.tryParse(strField(pickField(o, 'id', ['Id'])))?.round();
        if (id == null) continue;
        final content = strField(pickField(o, 'content', ['Content']));
        final optionsRaw = pickField(o, 'options', ['Options']);
        final options = <LifestyleOption>[];
        if (optionsRaw is List) {
          for (final opt in optionsRaw) {
            if (opt is! Map) continue;
            final m = Map<String, dynamic>.from(opt);
            final optId =
                num.tryParse(strField(pickField(m, 'id', ['Id'])))?.round();
            final optContent = strField(pickField(m, 'content', ['Content']));
            if (optId != null && optContent.isNotEmpty) {
              options.add(LifestyleOption(id: optId, content: optContent));
            }
          }
        }
        if (content.isEmpty || options.isEmpty) continue;
        questions.add(LifestyleQuestion(id: id, content: content, options: options));
      }
      questions.sort((a, b) => a.id.compareTo(b.id));
      return questions;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw ApiException(
        message: _extractErrorMessage(e) ?? 'Không tải được câu hỏi trắc nghiệm.',
        statusCode: e.response?.statusCode,
      );
    } catch (_) {
      throw ApiException(message: 'Không tải được câu hỏi trắc nghiệm.');
    }
  }

  Future<String> submitAnswers(List<int> selectedOptionIds) async {
    try {
      final response = await _dio.post<dynamic>(
        '/Lifestyle/submit',
        data: {
          'selectedOptionIds': selectedOptionIds,
          'SelectedOptionIds': selectedOptionIds,
        },
      );
      return _messageFromResponse(response.data, 'Lưu trắc nghiệm thành công.');
    } on DioException catch (e) {
      throw ApiException(
        message: _extractErrorMessage(e) ?? 'Gửi kết quả trắc nghiệm thất bại.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<bool> ensureQuizCompleted(String userId) async {
    if (userId.isEmpty) return false;
    final storage = await LifestyleStorage.create();
    if (storage.hasCompletedQuiz(userId)) return true;
    final answers = await getMyAnswers();
    if (answers.isNotEmpty) {
      await storage.setQuizCompleted(userId);
      return true;
    }
    return false;
  }

  Future<bool> hasCompletedQuiz({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      return ensureQuizCompleted(userId);
    }
    final answers = await getMyAnswers();
    return answers.isNotEmpty;
  }

  Future<List<SwipeDeckCard>> getGuestSwipeDeck({
    required List<int> selectedOptionIds,
    int limit = 50,
    bool includeSwiped = true,
  }) async {
    if (selectedOptionIds.isEmpty) return [];
    try {
      final response = await _dio.get<dynamic>(
        '/Lifestyle/guest-swipe-deck',
        queryParameters: {
          'limit': limit,
          'selectedOptionIds': selectedOptionIds.join(','),
          if (includeSwiped) 'includeSwiped': 'true',
        },
      );
      return _normalizeSwipeDeck(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<UserLifestyleAnswer>> getMyAnswers() async {
    try {
      final response = await _dio.get<dynamic>('/Lifestyle/my-answers');
      return _normalizeAnswers(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<SwipeDeckCard>> getSwipeDeck({
    int limit = 50,
    bool includeSwiped = true,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Lifestyle/swipe-deck',
        queryParameters: {
          'limit': limit,
          if (includeSwiped) 'includeSwiped': 'true',
        },
      );
      return _normalizeSwipeDeck(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> swipeUser(String targetUserId, bool isLike) async {
    try {
      await _dio.post<dynamic>(
        '/Lifestyle/swipe',
        queryParameters: {
          'targetUserId': targetUserId,
          'isLike': isLike.toString(),
        },
      );
    } catch (_) {}
  }

  Future<List<WishlistItem>> getMyLikes() async {
    try {
      final response = await _dio.get<dynamic>('/Lifestyle/my-likes');
      return _normalizeWishlist(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> removeLike(String targetUserId) async {
    try {
      await _dio.delete('/Lifestyle/my-likes/${Uri.encodeComponent(targetUserId)}');
    } catch (_) {}
  }

  Future<SwipeQuota> getSwipeQuota() async {
    try {
      final response = await _dio.get<dynamic>('/Lifestyle/swipe-quota');
      return _normalizeSwipeQuota(response.data);
    } catch (_) {
      return const SwipeQuota(
        isPremium: false,
        weeklyLimit: 5,
        usedThisWeek: 0,
        remaining: 5,
        weekResetAt: '',
      );
    }
  }

  Future<List<UserLifestyleAnswer>> getUserAnswers(String userId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Lifestyle/answers/${Uri.encodeComponent(userId)}',
      );
      return _normalizeAnswers(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<int> getMatchingScore(String targetUserId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Lifestyle/match/${Uri.encodeComponent(targetUserId)}',
      );
      if (response.data is Map) {
        final o = Map<String, dynamic>.from(response.data as Map);
        return num.tryParse(
              strField(pickField(o, 'matchingScore', ['MatchingScore'])),
            )?.round() ??
            0;
      }
    } catch (_) {}
    return 0;
  }

  Future<int?> _tenantRoomPrice(String userId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/TenantRoomProfile/user/${Uri.encodeComponent(userId)}',
      );
      final raw = response.data;
      Map<String, dynamic>? map;
      if (raw is Map) {
        final o = Map<String, dynamic>.from(raw);
        final data = o['data'] ?? o['Data'];
        map = data is Map ? Map<String, dynamic>.from(data) : o;
      }
      if (map == null) return null;
      final price = num.tryParse(
        strField(pickField(map, 'price', ['Price'])),
      );
      return price != null && price > 0 ? price.round() : null;
    } catch (_) {
      return null;
    }
  }

  Future<DiscoveryCard> enrichCard(SwipeDeckCard card) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Auth/user/${Uri.encodeComponent(card.userId)}',
      );
      final answers = await getUserAnswers(card.userId);
      final raw = response.data;
      Map<String, dynamic>? user;
      if (raw is Map) {
        user = normalizeAuthUser(Map<String, dynamic>.from(raw));
      }
      final displayName = user != null ? navProfileLabel(user) : 'Người dùng';
      final profileImageUrls = personalProfileImagesListFromRaw(user);
      final fallbackAvatarUrl = resolveUserAvatarUrl(user, displayName: displayName);
      final avatarUrl = profileImageUrls.isNotEmpty
          ? profileImageUrls.first
          : fallbackAvatarUrl;
      final bio = user != null
          ? strField(pickField(user, 'bio', ['Bio']))
          : '';
      final living = user != null
          ? strField(pickField(user, 'livingArea', ['LivingArea']))
          : '';
      final job = user != null
          ? strField(pickField(user, 'job', ['Job', 'occupation', 'Occupation']))
          : '';
      final dob = user != null ? profileDateOfBirthSeed(user) : '';
      final hasRoom = hasRoomFromAnswers(answers);
      TenantRoomProfile? tenantRoomProfile;
      int? roomPrice;
      if (hasRoom) {
        tenantRoomProfile =
            await TenantRoomRepository(_dio).getByUserId(card.userId);
        roomPrice = tenantRoomProfile?.price ?? await _tenantRoomPrice(card.userId);
      }
      final roomPriceLabel = hasRoom ? tenantRoomPriceLabel(roomPrice) : '';
      final gender = user != null
          ? profileGenderFromRaw(user['gender'] ?? user['Gender'])
          : 'other';
      return DiscoveryCard(
        userId: card.userId,
        matchingScore: card.matchingScore,
        displayName: displayName,
        avatarUrl: avatarUrl,
        profileImageUrls: profileImageUrls,
        fallbackAvatarUrl: fallbackAvatarUrl,
        bio: bio.isNotEmpty ? bio : null,
        location: living.isNotEmpty ? living : null,
        jobLabel: job.isNotEmpty ? jobLabelVi(job) : null,
        age: dob.isNotEmpty ? ageFromDateOfBirth(dob) : null,
        hasRoom: hasRoom,
        roomStatusLabel: roomStatusLabel(hasRoom),
        roomPriceLabel: roomPriceLabel,
        gender: gender,
        tenantRoomProfile: tenantRoomProfile,
      );
    } catch (_) {
      return DiscoveryCard(
        userId: card.userId,
        matchingScore: card.matchingScore,
        displayName: 'Người dùng',
        avatarUrl: avatarFallbackUrl('User'),
      );
    }
  }

  List<SwipeDeckCard> _normalizeSwipeDeck(dynamic raw) {
    return _unwrapList(raw).map((item) {
      if (item is! Map) return null;
      final o = Map<String, dynamic>.from(item);
      final userId = strField(
        pickField(o, 'userId', ['UserId', 'id', 'Id']),
      );
      if (userId.isEmpty) return null;
      final score = num.tryParse(
            strField(pickField(o, 'matchingScore', ['MatchingScore'])),
          )?.round() ??
          0;
      return SwipeDeckCard(userId: userId, matchingScore: score);
    }).whereType<SwipeDeckCard>().toList();
  }

  List<WishlistItem> _normalizeWishlist(dynamic raw) {
    return _unwrapList(raw).map((item) {
      if (item is! Map) return null;
      final o = Map<String, dynamic>.from(item);
      final userId = strField(pickField(o, 'userId', ['UserId']));
      if (userId.isEmpty) return null;
      final displayName = strField(
        pickField(o, 'displayName', ['DisplayName', 'name', 'Name']),
      );
      final avatar = strField(pickField(o, 'avatarUrl', ['AvatarUrl', 'avatar']));
      final score = num.tryParse(
            strField(pickField(o, 'matchingScore', ['MatchingScore'])),
          )?.round() ??
          0;
      return WishlistItem(
        userId: userId,
        displayName: displayName.isNotEmpty ? displayName : 'Người dùng',
        avatarUrl: avatar.isNotEmpty ? resolveMediaUrl(avatar) : avatarFallbackUrl(displayName),
        matchingScore: score,
        likedAt: strField(pickField(o, 'likedAt', ['LikedAt'])).isNotEmpty
            ? strField(pickField(o, 'likedAt', ['LikedAt']))
            : null,
      );
    }).whereType<WishlistItem>().toList();
  }

  SwipeQuota _normalizeSwipeQuota(dynamic raw) {
    if (raw is! Map) {
      return const SwipeQuota(
        isPremium: false,
        weeklyLimit: 5,
        usedThisWeek: 0,
        remaining: 5,
        weekResetAt: '',
      );
    }
    final o = Map<String, dynamic>.from(raw);
    final isPremium = o['isPremium'] == true || o['IsPremium'] == true;
    final weeklyLimit = num.tryParse(
      strField(pickField(o, 'weeklyLimit', ['WeeklyLimit'])),
    )?.round();
    final used = num.tryParse(
          strField(pickField(o, 'usedThisWeek', ['UsedThisWeek'])),
        )?.round() ??
        0;
    final remaining = num.tryParse(
      strField(pickField(o, 'remaining', ['Remaining'])),
    )?.round();
    final reset = strField(pickField(o, 'weekResetAt', ['WeekResetAt']));
    return SwipeQuota(
      isPremium: isPremium,
      weeklyLimit: weeklyLimit,
      usedThisWeek: used,
      remaining: remaining,
      weekResetAt: reset,
    );
  }

  List<UserLifestyleAnswer> _normalizeAnswers(dynamic raw) {
    return _unwrapList(raw).map((item) {
      if (item is! Map) return null;
      final o = Map<String, dynamic>.from(item);
      final qId = num.tryParse(
        strField(pickField(o, 'questionId', ['QuestionId'])),
      )?.round();
      final oId = num.tryParse(
        strField(pickField(o, 'optionId', ['OptionId'])),
      )?.round();
      if (qId == null || oId == null) return null;
      return UserLifestyleAnswer(
        questionId: qId,
        questionContent:
            strField(pickField(o, 'questionContent', ['QuestionContent'])),
        optionId: oId,
        optionContent:
            strField(pickField(o, 'optionContent', ['OptionContent'])),
      );
    }).whereType<UserLifestyleAnswer>().toList();
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    final value = map['value'] ?? map['Value'];
    if (value is List) return value;
    final nested = pickField(map, 'data', ['items', r'$values']);
    if (nested is List) return nested;
    return [];
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = strField(
        pickField(Map<String, dynamic>.from(data), 'message', ['Message', 'title', 'Title']),
      );
      if (msg.isNotEmpty) return msg;
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return e.message;
  }

  String _messageFromResponse(dynamic raw, String fallback) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is Map) {
      final m = strField(
        pickField(Map<String, dynamic>.from(raw), 'message', ['Message']),
      );
      if (m.isNotEmpty) return m;
    }
    return fallback;
  }
}
