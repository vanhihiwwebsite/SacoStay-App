import '../../models/room_post.dart';

String normalizeLocationKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool cityMatches(
  String? roomCity,
  String? roomAddress,
  String filterCity,
) {
  if (filterCity == 'all') return true;
  final key = normalizeLocationKey(filterCity);
  final cityKey = normalizeLocationKey(roomCity ?? '');
  final addrKey = normalizeLocationKey(roomAddress ?? '');
  if (cityKey.isNotEmpty &&
      (cityKey == key || cityKey.contains(key) || key.contains(cityKey))) {
    return true;
  }
  if (addrKey.contains(key)) return true;
  if (key == 'tp hcm' &&
      (addrKey.contains('ho chi minh') || addrKey.contains('hcm'))) {
    return true;
  }
  if (key == 'ha noi' && addrKey.contains('ha noi')) return true;
  return false;
}

bool districtMatches(
  String? roomDistrict,
  String? roomAddress,
  String filterDistrict,
) {
  if (filterDistrict == 'all') return true;
  final key = normalizeLocationKey(filterDistrict);
  final dKey = normalizeLocationKey(roomDistrict ?? '');
  final addrKey = normalizeLocationKey(roomAddress ?? '');
  return (dKey.isNotEmpty && dKey.contains(key)) || addrKey.contains(key);
}

bool priceInRange(int? price, int min, int max) {
  if (price == null || price <= 0) return true;
  return price >= min && price <= max;
}

bool roomMatchesSearch(RoomPostSummary room, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final haystack = [
    room.title,
    room.address,
    room.city,
    room.district,
    room.description,
    ...room.amenities,
  ].whereType<String>().join(' ').toLowerCase();
  return haystack.contains(q);
}

bool maxOccupantsMatches(RoomPostSummary room, String filter) {
  if (filter == 'all') return true;
  final max = room.maxPeople;
  if (max == null || max <= 0) return true;
  final n = int.tryParse(filter);
  if (n == null) return true;
  if (n >= 4) return max >= 4;
  return max == n;
}

bool amenitiesMatch(RoomPostSummary room, Set<String> selected) {
  if (selected.isEmpty) return true;
  final roomAmenities = room.amenities.map(normalizeLocationKey).toSet();
  for (final a in selected) {
    final key = normalizeLocationKey(a);
    if (!roomAmenities.any((ra) => ra.contains(key) || key.contains(ra))) {
      return false;
    }
  }
  return true;
}

List<RoomPostSummary> applyRoomFilters(
  List<RoomPostSummary> rooms,
  RoomListFilters filters,
) {
  return rooms.where((room) {
    if (!cityMatches(room.city, room.address, filters.city)) return false;
    if (!districtMatches(room.district, room.address, filters.district)) {
      return false;
    }
    if (!priceInRange(room.price, filters.priceMin, filters.priceMax)) {
      return false;
    }
    if (!maxOccupantsMatches(room, filters.maxOccupants)) return false;
    if (!amenitiesMatch(room, filters.amenities)) return false;
    if (!roomMatchesSearch(room, filters.searchQuery)) return false;
    return true;
  }).toList();
}

int activeFilterCount(RoomListFilters filters) {
  var count = 0;
  if (filters.city != 'all') count++;
  if (filters.district != 'all') count++;
  if (filters.priceMin > 0 || filters.priceMax < 50000000) count++;
  if (filters.maxOccupants != 'all') count++;
  count += filters.amenities.length;
  return count;
}

String priceShort(int? price) {
  if (price == null || price <= 0) return 'Liên hệ';
  final millions = price / 1000000;
  if (millions >= 1) {
    final rounded = millions == millions.roundToDouble()
        ? millions.toStringAsFixed(0)
        : millions.toStringAsFixed(1);
    return '${rounded}tr';
  }
  return '${(price / 1000).round()}k';
}
