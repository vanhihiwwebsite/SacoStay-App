class TenantRoomProfile {
  const TenantRoomProfile({
    this.userId,
    this.city,
    this.district,
    this.maxPeople,
    this.price,
    this.amenities = const [],
    this.extraNotes,
    this.images = const [],
  });

  final String? userId;
  final String? city;
  final String? district;
  final int? maxPeople;
  final int? price;
  final List<String> amenities;
  final String? extraNotes;
  final List<String> images;

  bool get hasContent =>
      (city != null && city!.isNotEmpty) ||
      (district != null && district!.isNotEmpty) ||
      (price != null && price! > 0) ||
      images.isNotEmpty;
}
