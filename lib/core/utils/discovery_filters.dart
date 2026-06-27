import '../../models/lifestyle.dart';

enum DiscoveryGenderFilter { all, male, female }
enum DiscoveryHasRoomFilter { all, yes, no }
enum DiscoveryRoomPriceFilter { all, under2m, twoTo3m, threeTo5m, over5m }
enum DiscoveryRoomDistrictFilter {
  all,
  cauGiay,
  dongDa,
  haiBaTrung,
  binhThanh,
  quan7,
}

class DiscoveryFilters {
  const DiscoveryFilters({
    this.gender = DiscoveryGenderFilter.all,
    this.minAge = 18,
    this.maxAge = 30,
    this.minCompatibility = 0,
    this.hasRoom = DiscoveryHasRoomFilter.all,
    this.roomPrice = DiscoveryRoomPriceFilter.all,
    this.roomDistrict = DiscoveryRoomDistrictFilter.all,
  });

  final DiscoveryGenderFilter gender;
  final int minAge;
  final int maxAge;
  final int minCompatibility;
  final DiscoveryHasRoomFilter hasRoom;
  final DiscoveryRoomPriceFilter roomPrice;
  final DiscoveryRoomDistrictFilter roomDistrict;

  DiscoveryFilters copyWith({
    DiscoveryGenderFilter? gender,
    int? minAge,
    int? maxAge,
    int? minCompatibility,
    DiscoveryHasRoomFilter? hasRoom,
    DiscoveryRoomPriceFilter? roomPrice,
    DiscoveryRoomDistrictFilter? roomDistrict,
  }) {
    return DiscoveryFilters(
      gender: gender ?? this.gender,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      minCompatibility: minCompatibility ?? this.minCompatibility,
      hasRoom: hasRoom ?? this.hasRoom,
      roomPrice: roomPrice ?? this.roomPrice,
      roomDistrict: roomDistrict ?? this.roomDistrict,
    );
  }
}

const defaultDiscoveryFilters = DiscoveryFilters();

String profileGenderFromRaw(dynamic gender) {
  if (gender == true || gender == 'male') return 'male';
  if (gender == false || gender == 'female') return 'female';
  return 'other';
}

DiscoveryRoomPriceFilter? _priceBucketFromLabel(String label) {
  final t = label.toLowerCase();
  final matches = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:triệu|tr|m|k)?', caseSensitive: false)
      .allMatches(t);
  final nums = matches.map((m) {
    var n = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
    final token = m.group(0)!.toLowerCase();
    if (token.contains('triệu') || token.contains('tr') || (n < 100 && n > 0)) {
      if (n < 100) n *= 1000000;
    } else if (token.contains('k')) {
      n *= 1000;
    }
    return n;
  }).toList();

  final value = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
  if (value == 0) {
    if (t.contains('dưới 2') || t.contains('under2')) {
      return DiscoveryRoomPriceFilter.under2m;
    }
    if (t.contains('2-3') || t.contains('2 – 3')) {
      return DiscoveryRoomPriceFilter.twoTo3m;
    }
    if (t.contains('3-5') || t.contains('3 – 5')) {
      return DiscoveryRoomPriceFilter.threeTo5m;
    }
    if (t.contains('trên 5') || t.contains('over5')) {
      return DiscoveryRoomPriceFilter.over5m;
    }
    return null;
  }
  if (value < 2000000) return DiscoveryRoomPriceFilter.under2m;
  if (value <= 3000000) return DiscoveryRoomPriceFilter.twoTo3m;
  if (value <= 5000000) return DiscoveryRoomPriceFilter.threeTo5m;
  return DiscoveryRoomPriceFilter.over5m;
}

bool roomPriceMatchesFilter(String priceLabel, DiscoveryRoomPriceFilter filter) {
  if (filter == DiscoveryRoomPriceFilter.all) return true;
  final bucket = _priceBucketFromLabel(priceLabel);
  return bucket == filter;
}

String _districtLabel(DiscoveryRoomDistrictFilter d) {
  switch (d) {
    case DiscoveryRoomDistrictFilter.cauGiay:
      return 'Cầu Giấy';
    case DiscoveryRoomDistrictFilter.dongDa:
      return 'Đống Đa';
    case DiscoveryRoomDistrictFilter.haiBaTrung:
      return 'Hai Bà Trưng';
    case DiscoveryRoomDistrictFilter.binhThanh:
      return 'Bình Thạnh';
    case DiscoveryRoomDistrictFilter.quan7:
      return 'Quận 7';
    default:
      return '';
  }
}

bool matchesDiscoveryFilters(DiscoveryCard card, DiscoveryFilters filters) {
  if (card.matchingScore < filters.minCompatibility) return false;

  if (filters.gender != DiscoveryGenderFilter.all) {
    final g = card.gender;
    if (filters.gender == DiscoveryGenderFilter.male && g != 'male') return false;
    if (filters.gender == DiscoveryGenderFilter.female && g != 'female') return false;
  }

  if (card.age != null) {
    if (card.age! < filters.minAge || card.age! > filters.maxAge) return false;
  }

  if (filters.hasRoom == DiscoveryHasRoomFilter.yes && !card.hasRoom) return false;
  if (filters.hasRoom == DiscoveryHasRoomFilter.no && card.hasRoom) return false;

  if (filters.hasRoom == DiscoveryHasRoomFilter.yes) {
    if (filters.roomDistrict != DiscoveryRoomDistrictFilter.all) {
      final loc = (card.location ?? '').toLowerCase();
      final district = _districtLabel(filters.roomDistrict).toLowerCase();
      if (!loc.contains(district)) return false;
    }
    if (!roomPriceMatchesFilter(card.roomPriceLabel, filters.roomPrice)) {
      return false;
    }
  }

  return true;
}
