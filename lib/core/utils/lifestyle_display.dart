import '../../models/lifestyle.dart';
import '../../models/tenant_room_profile.dart';
import 'json_normalize.dart';

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
    hasRoom ? 'Đã có phòng trọ' : 'Chưa có phòng trọ';

bool isRoomStatusQuestion(String questionContent) {
  final c = questionContent.toLowerCase();
  if (c.contains('tình trạng phòng')) return true;
  if (c.contains('phòng trọ') || c.contains('phòng ở')) return true;
  return c.contains('phòng') && (c.contains('trọ') || c.contains('thuê'));
}

bool isRoomPriceQuestion(String questionContent) {
  final c = questionContent.toLowerCase();
  if (c.contains('tiền trọ') || c.contains('tiền phòng')) return true;
  return (c.contains('giá') || c.contains('ngân sách')) &&
      (c.contains('phòng') || c.contains('trọ'));
}

List<UserLifestyleAnswer> lifestyleAnswersForDisplay(List<UserLifestyleAnswer> answers) {
  return answers
      .where((a) =>
          !isRoomStatusQuestion(a.questionContent) &&
          !isRoomPriceQuestion(a.questionContent))
      .toList();
}

const _questionLabelById = <int, String>{
  2: 'Giờ Giấc',
  5: 'Mức độ sạch sẽ của người ở ghép',
  7: 'Mong muốn mối quan hệ với người ở ghép',
  11: 'Tiêu chí lựa chọn người ở ghép',
  22: 'Tình trạng phòng',
};

class _CategoryRule {
  const _CategoryRule(this.pattern, this.label);
  final RegExp pattern;
  final String label;
}

final _categoryRules = <_CategoryRule>[
  _CategoryRule(RegExp(r'tình trạng phòng|đã có phòng|chưa có phòng|đang tìm phòng', caseSensitive: false), 'Tình trạng phòng'),
  _CategoryRule(RegExp(r'giá phòng|ngân sách|mức giá|tiền trọ|tiền phòng', caseSensitive: false), 'Ngân sách thuê'),
  _CategoryRule(RegExp(r'giờ.*(ngủ|về|sinh hoạt)|giờ giấc|thức khuya|dậy sớm', caseSensitive: false), 'Giờ Giấc'),
  _CategoryRule(RegExp(r'thoải mái.*(hút thuốc|người hút)|sống cùng.*(người )?hút thuốc|cảm thấy thoải mái.*hút thuốc', caseSensitive: false), 'Thoải mái khi ở gần người hút thuốc'),
  _CategoryRule(RegExp(r'học tập|làm việc.*(nhà|tại nhà)|wfh|work from home', caseSensitive: false), 'Học / làm việc tại nhà'),
  _CategoryRule(RegExp(r'môi trường sống|yên tĩnh|tiếng ồn|ồn ào', caseSensitive: false), 'Môi trường sống'),
  _CategoryRule(RegExp(r'gọn gàng|ngăn nắp', caseSensitive: false), 'Gọn gàng & ngăn nắp'),
  _CategoryRule(RegExp(r'mức độ sạch sẽ.*roommate|sạch sẽ.*đồng phòng|kỳ vọng.*sạch', caseSensitive: false), 'Kỳ vọng vệ sinh'),
  _CategoryRule(RegExp(r'vệ sinh|dọn dẹp|lau chùi', caseSensitive: false), 'Vệ sinh chung'),
  _CategoryRule(RegExp(r'nấu ăn|bếp|nồi niêu', caseSensitive: false), 'Nấu ăn'),
  _CategoryRule(RegExp(r'tần suất.*khách|khách.*thường xuyên|khách.*bao lâu', caseSensitive: false), 'Tần suất khách'),
  _CategoryRule(RegExp(r'khách|bạn bè.*(qua|nhà|đến)', caseSensitive: false), 'Khách đến nhà'),
  _CategoryRule(RegExp(r'(^bạn )?có hút thuốc|bạn hút thuốc|thói quen hút thuốc|hút thuốc không|hút thuốc hay', caseSensitive: false), 'Hút thuốc'),
  _CategoryRule(RegExp(r'hút thuốc|thuốc lá', caseSensitive: false), 'Hút thuốc'),
  _CategoryRule(RegExp(r'thú cưng|pet', caseSensitive: false), 'Thú cưng'),
  _CategoryRule(RegExp(r'mối quan hệ.*roommate|quan hệ.*đồng phòng', caseSensitive: false), 'Quan hệ với roommate'),
  _CategoryRule(RegExp(r'góp ý|phản hồi.*roommate|nhắc nhở', caseSensitive: false), 'Cách góp ý'),
  _CategoryRule(RegExp(r'không gian riêng|riêng tư', caseSensitive: false), 'Không gian riêng'),
  _CategoryRule(RegExp(r'trách nhiệm|đúng hạn|chia việc|hóa đơn', caseSensitive: false), 'Trách nhiệm chung'),
  _CategoryRule(RegExp(r'bất đồng|tranh chấp|mâu thuẫn', caseSensitive: false), 'Xử lý bất đồng'),
  _CategoryRule(RegExp(r'căng thẳng|mệt mỏi|stress', caseSensitive: false), 'Khi căng thẳng'),
  _CategoryRule(RegExp(r'cảm thấy.*roommate.*(đồ|dùng)|dùng chung.*đồ|mượn đồ', caseSensitive: false), 'Dùng chung đồ'),
  _CategoryRule(RegExp(r'roommate.*(vào phòng|phòng ngủ|không gian)', caseSensitive: false), 'Vào phòng riêng'),
  _CategoryRule(RegExp(r'chia sẻ.*(tiền|điện|nước)|chi phí chung', caseSensitive: false), 'Chia chi phí'),
  _CategoryRule(RegExp(r'chia sẻ|đồ dùng', caseSensitive: false), 'Chia sẻ đồ dùng'),
  _CategoryRule(RegExp(r'cuối tuần|weekend', caseSensitive: false), 'Cuối tuần'),
  _CategoryRule(RegExp(r'nghe nhạc|tiệc|party|giải trí', caseSensitive: false), 'Giải trí'),
  _CategoryRule(RegExp(r'roommate', caseSensitive: false), 'Thói quen đồng phòng'),
  _CategoryRule(RegExp(r'làm tại nhà', caseSensitive: false), 'Làm tại nhà'),
  _CategoryRule(RegExp(r'phòng trọ|đang ở', caseSensitive: false), 'Tình trạng phòng'),
];

String _shortenQuestionFallback(String questionContent) {
  final q = questionContent.trim();
  if (q.isEmpty) return 'Lối sống';
  var cleaned = q.replaceFirst(RegExp(r'^bạn\s+', caseSensitive: false), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[?.!]+$'), '');
  if (cleaned.length <= 42) {
    return cleaned.isEmpty ? cleaned : '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }
  return '${cleaned.substring(0, 40).trim()}…';
}

String lifestyleCategoryLabel(String questionContent) {
  final q = questionContent.trim();
  for (final rule in _categoryRules) {
    if (rule.pattern.hasMatch(q)) return rule.label;
  }
  return _shortenQuestionFallback(q);
}

String lifestyleAnswerLabel(UserLifestyleAnswer answer) {
  final byId = _questionLabelById[answer.questionId];
  if (byId != null) return byId;
  return lifestyleCategoryLabel(answer.questionContent);
}

bool isVerifiedUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (pickField(user, 'isVerified', ['IsVerified']) == true) return true;
  final s = strField(
    pickField(user, 'verificationStatus', ['VerificationStatus']),
  ).toLowerCase();
  return s == 'verified' || s == 'approved' || s == 'completed';
}

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
