class TenantRoomProfileForm {
  TenantRoomProfileForm({
    this.city = 'all',
    this.district = 'all',
    this.maxPeople = 2,
    this.priceInput = '',
    this.amenities = const [],
    this.extraNotes = '',
  });

  String city;
  String district;
  int maxPeople;
  String priceInput;
  List<String> amenities;
  String extraNotes;
}

TenantRoomProfileForm emptyTenantRoomProfileForm() => TenantRoomProfileForm();

const tenantRoomAmenityOptions = [
  (value: 'Điều hòa', icon: '❄️'),
  (value: 'Ban công', icon: '🌿'),
  (value: 'WiFi', icon: '📶'),
  (value: 'Nóng lạnh', icon: '🚿'),
  (value: 'Máy giặt', icon: '👕'),
  (value: 'Bếp riêng', icon: '🍳'),
  (value: 'Thang máy', icon: '🛗'),
  (value: 'Bảo vệ 24/7', icon: '🛡️'),
  (value: 'Chỗ để xe', icon: '🏍️'),
  (value: 'Tủ lạnh', icon: '🧊'),
  (value: 'Full nội thất', icon: '🛋️'),
  (value: 'Hồ bơi chung', icon: '🏊'),
];

const tenantRoomMaxPeopleOptions = [
  (value: 1, label: '1 người'),
  (value: 2, label: '2 người'),
  (value: 3, label: '3 người'),
  (value: 4, label: '4+ người'),
];

int? parseTenantRoomPriceInput(String input) {
  final t = input.trim().replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return null;
  final normalized = t.replaceAll('.', '').replaceAll(',', '');
  final n = int.tryParse(normalized);
  if (n == null || n <= 0) return null;
  return n;
}

String formatTenantRoomPriceInput(int? price) {
  if (price == null || price <= 0) return '';
  return price.toString();
}

bool isTenantRoomProfileComplete(TenantRoomProfileForm form) {
  return form.city.isNotEmpty &&
      form.city != 'all' &&
      form.district.isNotEmpty &&
      form.district != 'all' &&
      form.maxPeople >= 1;
}

Map<String, dynamic> tenantRoomProfilePayload(TenantRoomProfileForm form) {
  final price = parseTenantRoomPriceInput(form.priceInput);
  return {
    'city': form.city,
    'district': form.district,
    'maxPeople': form.maxPeople,
    if (price != null) 'price': price,
    'amenities': form.amenities,
    if (form.extraNotes.trim().isNotEmpty) 'extraNotes': form.extraNotes.trim(),
  };
}
