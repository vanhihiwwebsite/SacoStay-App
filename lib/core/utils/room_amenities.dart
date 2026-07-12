import '../../models/room_post.dart';
import 'vietnam_districts.dart';

/// Amenities landlords can select when creating a listing.
const landlordAmenityValues = [
  'Điều hòa',
  'Nóng lạnh',
  'Máy giặt',
  'Ban công',
  'Thang máy',
  'Bếp riêng',
  'Bảo vệ 24/7',
  'Chỗ để xe',
  'WiFi',
  'Tủ lạnh',
];

const fullFurnitureAmenity = 'Full nội thất';

const roomFilterAmenityOptions = <FilterChipOption>[
  FilterChipOption(value: 'Điều hòa', label: '❄️ Điều hòa'),
  FilterChipOption(value: 'Nóng lạnh', label: '🚿 Nóng lạnh'),
  FilterChipOption(value: 'Máy giặt', label: '👕 Máy giặt'),
  FilterChipOption(value: 'Ban công', label: '🌿 Ban công'),
  FilterChipOption(value: 'Thang máy', label: '🛗 Thang máy'),
  FilterChipOption(value: 'Bếp riêng', label: '🍳 Bếp riêng'),
  FilterChipOption(value: 'Bảo vệ 24/7', label: '🛡️ Bảo vệ 24/7'),
  FilterChipOption(value: 'Chỗ để xe', label: '🏍️ Chỗ để xe'),
  FilterChipOption(value: 'WiFi', label: '📶 WiFi'),
  FilterChipOption(value: 'Tủ lạnh', label: '🧊 Tủ lạnh'),
  FilterChipOption(value: fullFurnitureAmenity, label: '🛋️ Full nội thất'),
];

Set<String> toggleRoomFilterAmenity(Set<String> current, String value, bool selected) {
  final next = Set<String>.from(current);
  if (value == fullFurnitureAmenity) {
    if (selected) {
      next.addAll(landlordAmenityValues);
    } else {
      for (final a in landlordAmenityValues) {
        next.remove(a);
      }
    }
    return next;
  }

  if (selected) {
    next.add(value);
  } else {
    next.remove(value);
  }
  return next;
}

/// Full nội thất is a UI shortcut only — active when every landlord amenity is selected.
bool isFullFurnitureFilterActive(Set<String> amenities) {
  return landlordAmenityValues.every(amenities.contains);
}

bool isRoomFilterAmenitySelected(Set<String> amenities, String value) {
  if (value == fullFurnitureAmenity) {
    return isFullFurnitureFilterActive(amenities);
  }
  return amenities.contains(value);
}

void applyAmenityToggle(RoomListFilters filters, String value, bool selected) {
  final next = toggleRoomFilterAmenity(filters.amenities, value, selected);
  filters.amenities
    ..clear()
    ..addAll(next);
}
