import '../core/utils/vip_tier.dart' show VipTier;

class RoomPostSummary {
  const RoomPostSummary({
    required this.id,
    this.landlordUserId,
    required this.title,
    this.price,
    this.address,
    this.city,
    this.district,
    this.area,
    this.maxPeople,
    this.currentPeople,
    this.imageUrl,
    this.status,
    this.viewCount,
    this.vipTier = VipTier.free,
    this.amenities = const [],
    this.description,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? landlordUserId;
  final String title;
  final int? price;
  final String? address;
  final String? city;
  final String? district;
  final double? area;
  final int? maxPeople;
  final int? currentPeople;
  final String? imageUrl;
  final String? status;
  final int? viewCount;
  final VipTier vipTier;
  final List<String> amenities;
  final String? description;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      latitude != null && longitude != null && latitude! != 0 && longitude! != 0;
}

class RoomOccupant {
  const RoomOccupant({
    required this.id,
    required this.name,
    this.avatar,
    this.age,
    this.occupation,
  });

  final String id;
  final String name;
  final String? avatar;
  final int? age;
  final String? occupation;
}

class RoomPostDetail extends RoomPostSummary {
  const RoomPostDetail({
    required super.id,
    super.landlordUserId,
    required super.title,
    super.price,
    super.address,
    super.city,
    super.district,
    super.area,
    super.maxPeople,
    super.currentPeople,
    super.imageUrl,
    super.status,
    super.viewCount,
    super.vipTier = VipTier.free,
    super.amenities = const [],
    super.description,
    super.latitude,
    super.longitude,
    this.images = const [],
    this.nearbyLandmarks = const [],
    this.landlordPhone,
    this.occupants = const [],
  });

  final List<String> images;
  final List<String> nearbyLandmarks;
  final String? landlordPhone;
  final List<RoomOccupant> occupants;

  List<String> get galleryImages {
    if (images.isNotEmpty) return images;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return [];
  }
}

class RoomListFilters {
  RoomListFilters({
    this.city = 'all',
    this.district = 'all',
    this.priceMin = 0,
    this.priceMax = 50000000,
    this.maxOccupants = 'all',
    this.amenities = const {},
    this.searchQuery = '',
  });

  String city;
  String district;
  int priceMin;
  int priceMax;
  String maxOccupants;
  Set<String> amenities;
  String searchQuery;

  RoomListFilters copy() => RoomListFilters(
        city: city,
        district: district,
        priceMin: priceMin,
        priceMax: priceMax,
        maxOccupants: maxOccupants,
        amenities: Set<String>.from(amenities),
        searchQuery: searchQuery,
      );
}
