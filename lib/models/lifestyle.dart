import 'tenant_room_profile.dart';

class LifestyleOption {
  const LifestyleOption({required this.id, required this.content});

  final int id;
  final String content;
}

class LifestyleQuestion {
  const LifestyleQuestion({
    required this.id,
    required this.content,
    required this.options,
  });

  final int id;
  final String content;
  final List<LifestyleOption> options;
}

class SwipeDeckCard {
  const SwipeDeckCard({
    required this.userId,
    required this.matchingScore,
  });

  final String userId;
  final int matchingScore;
}

class WishlistItem {
  const WishlistItem({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.matchingScore,
    this.likedAt,
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final int matchingScore;
  final String? likedAt;
}

class SwipeQuota {
  const SwipeQuota({
    required this.isPremium,
    required this.weeklyLimit,
    required this.usedThisWeek,
    required this.remaining,
    required this.weekResetAt,
  });

  final bool isPremium;
  final int? weeklyLimit;
  final int usedThisWeek;
  final int? remaining;
  final String weekResetAt;
}

class UserLifestyleAnswer {
  const UserLifestyleAnswer({
    required this.questionId,
    required this.questionContent,
    required this.optionId,
    required this.optionContent,
  });

  final int questionId;
  final String questionContent;
  final int optionId;
  final String optionContent;
}

class DiscoveryCard {
  const DiscoveryCard({
    required this.userId,
    required this.matchingScore,
    required this.displayName,
    required this.avatarUrl,
    this.profileImageUrls = const [],
    this.fallbackAvatarUrl,
    this.bio,
    this.location,
    this.jobLabel,
    this.age,
    this.hasRoom = false,
    this.roomStatusLabel = 'Chưa có phòng',
    this.roomPriceLabel = '',
    this.gender = 'other',
    this.tenantRoomProfile,
  });

  final String userId;
  final int matchingScore;
  final String displayName;
  final String avatarUrl;
  final List<String> profileImageUrls;
  final String? fallbackAvatarUrl;
  final String? bio;
  final String? location;
  final String? jobLabel;
  final int? age;
  final bool hasRoom;
  final String roomStatusLabel;
  final String roomPriceLabel;
  final String gender;
  final TenantRoomProfile? tenantRoomProfile;

  bool get canOpenTenantRoomDetails =>
      hasRoom && tenantRoomProfile != null && tenantRoomProfile!.hasContent;

  String imageAt(int index) {
    if (profileImageUrls.isNotEmpty) {
      return profileImageUrls[index % profileImageUrls.length];
    }
    return avatarUrl;
  }
}
