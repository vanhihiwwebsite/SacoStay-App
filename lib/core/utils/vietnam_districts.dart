class FilterChipOption {
  const FilterChipOption({required this.value, required this.label});

  final String value;
  final String label;
}

const hanoiDistricts = [
  'Ba Đình',
  'Hoàn Kiếm',
  'Tây Hồ',
  'Long Biên',
  'Cầu Giấy',
  'Đống Đa',
  'Hai Bà Trưng',
  'Hoàng Mai',
  'Thanh Xuân',
  'Hà Đông',
  'Nam Từ Liêm',
  'Bắc Từ Liêm',
  'Đông Anh',
  'Gia Lâm',
  'Sóc Sơn',
  'Thanh Trì',
  'Hoài Đức',
  'Thường Tín',
  'Sơn Tây',
];

const hcmDistricts = [
  'Quận 1',
  'Quận 3',
  'Quận 4',
  'Quận 5',
  'Quận 6',
  'Quận 7',
  'Quận 8',
  'Quận 10',
  'Quận 11',
  'Quận 12',
  'Bình Thạnh',
  'Phú Nhuận',
  'Tân Bình',
  'Tân Phú',
  'Gò Vấp',
  'Bình Tân',
  'Thủ Đức',
  'Hóc Môn',
  'Củ Chi',
  'Bình Chánh',
  'Nhà Bè',
];

const filterCityOptions = [
  FilterChipOption(value: 'all', label: 'Tất cả'),
  FilterChipOption(value: 'Hà Nội', label: 'Hà Nội'),
  FilterChipOption(value: 'TP.HCM', label: 'TP.HCM'),
];

List<FilterChipOption> districtFilterOptions(String city) {
  const all = FilterChipOption(value: 'all', label: 'Tất cả');
  if (city == 'Hà Nội') {
    return [
      all,
      ...hanoiDistricts.map((d) => FilterChipOption(value: d, label: d)),
    ];
  }
  if (city == 'TP.HCM') {
    return [
      all,
      ...hcmDistricts.map((d) => FilterChipOption(value: d, label: d)),
    ];
  }
  return [
    all,
    ...hanoiDistricts.map((d) => FilterChipOption(value: d, label: d)),
    ...hcmDistricts.map((d) => FilterChipOption(value: d, label: d)),
  ];
}

const amenityOptions = [
  FilterChipOption(value: 'Điều hòa', label: '❄️ Điều hòa'),
  FilterChipOption(value: 'Ban công', label: '🌿 Ban công'),
  FilterChipOption(value: 'WiFi', label: '📶 WiFi'),
  FilterChipOption(value: 'Nóng lạnh', label: '🚿 Nóng lạnh'),
  FilterChipOption(value: 'Máy giặt', label: '👕 Máy giặt'),
  FilterChipOption(value: 'Bếp riêng', label: '🍳 Bếp riêng'),
  FilterChipOption(value: 'Thang máy', label: '🛗 Thang máy'),
  FilterChipOption(value: 'Bảo vệ 24/7', label: '🛡️ Bảo vệ 24/7'),
  FilterChipOption(value: 'Chỗ để xe', label: '🏍️ Chỗ để xe'),
  FilterChipOption(value: 'Tủ lạnh', label: '🧊 Tủ lạnh'),
  FilterChipOption(value: 'Full nội thất', label: '🛋️ Full nội thất'),
  FilterChipOption(value: 'Hồ bơi chung', label: '🏊 Hồ bơi chung'),
];

const maxOccupantOptions = [
  FilterChipOption(value: 'all', label: 'Tất cả'),
  FilterChipOption(value: '1', label: '1 người'),
  FilterChipOption(value: '2', label: '2 người'),
  FilterChipOption(value: '3', label: '3 người'),
  FilterChipOption(value: '4', label: '4+ người'),
];

const priceSliderMin = 0;
const priceSliderMax = 50000000;
