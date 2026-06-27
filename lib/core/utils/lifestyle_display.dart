import '../../models/lifestyle.dart';
import '../../models/tenant_room_profile.dart';

bool hasRoomFromAnswers(List<UserLifestyleAnswer> answers) {
  for (final a in answers) {
    final q = a.questionContent.toLowerCase();
    if (!q.contains('phòng') && !q.contains('room')) continue;
    final opt = a.optionContent.toLowerCase();
    if (opt.contains('chưa') || opt.contains('không')) return false;
    if (opt.contains('có') || opt.contains('đã')) return true;
  }
  return false;
}

String roomStatusLabel(bool hasRoom) =>
    hasRoom ? 'Đã có phòng' : 'Chưa có phòng';

String tenantRoomPriceLabel(int? price) {
  if (price == null || price <= 0) return '';
  final millions = price / 1000000;
  if (millions >= 0.1 && millions < 10000) {
    final formatted = millions == millions.roundToDouble()
        ? '${millions.round()}'
        : millions.toStringAsFixed(1).replaceAll('.', ',');
    return '$formatted triệu/tháng';
  }
  return '${price.toStringAsFixed(0)}đ/tháng';
}

String jobLabelVi(String? job) {
  final j = (job ?? '').trim().toLowerCase();
  if (j.isEmpty) return 'Chưa cập nhật';
  if (j == 'student' || j.contains('sinh viên')) return 'Sinh viên';
  if (j == 'fresher') return 'Mới đi làm';
  if (j == 'working' || j.contains('đi làm')) return 'Đã đi làm';
  return job ?? 'Chưa cập nhật';
}

String genderLabelVi(dynamic gender) {
  if (gender == true || gender == 'male') return 'Nam';
  if (gender == false || gender == 'female') return 'Nữ';
  return 'Khác';
}

int? ageFromDateOfBirth(String? dob) {
  if (dob == null || dob.isEmpty) return null;
  final d = DateTime.tryParse(dob.length >= 10 ? dob.substring(0, 10) : dob);
  if (d == null) return null;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
    age--;
  }
  return age >= 0 && age < 120 ? age : null;
}

String tenantRoomLocationLabel(TenantRoomProfile? profile) {
  if (profile == null) return 'Chưa cập nhật';
  final parts = <String>[];
  final district = profile.district?.trim() ?? '';
  final city = profile.city?.trim() ?? '';
  if (district.isNotEmpty && district != 'all') parts.add(district);
  if (city.isNotEmpty && city != 'all') parts.add(city);
  return parts.isEmpty ? 'Chưa cập nhật' : parts.join(', ');
}

String tenantRoomMaxPeopleLabel(int? maxPeople) {
  if (maxPeople == null || maxPeople < 1) return 'Chưa cập nhật';
  if (maxPeople >= 4) return '4+ người';
  return '$maxPeople người';
}

String cardMetaLine(DiscoveryCard card) {
  final parts = <String>[];
  if (card.roomPriceLabel.isNotEmpty) parts.add(card.roomPriceLabel);
  if (card.location != null && card.location!.isNotEmpty) {
    parts.add(card.location!);
  }
  return parts.join(' · ');
}

String cardTitleLine(DiscoveryCard card) {
  if (card.age != null) return '${card.displayName} ${card.age}';
  return card.displayName;
}
