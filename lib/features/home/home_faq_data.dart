class HomeFaqItem {
  const HomeFaqItem({
    required this.id,
    required this.question,
    required this.shortAnswer,
    required this.detailPath,
    required this.ctaLabel,
  });

  final String id;
  final String question;
  final String shortAnswer;
  final String detailPath;
  final String ctaLabel;
}

const homeFaqItems = [
  HomeFaqItem(
    id: 'pricing',
    question: 'SacoStay có mất phí không?',
    shortAnswer:
        'SacoStay áp dụng mô hình Freemium. Sinh viên có thể tìm kiếm phòng trọ và sử dụng các tính năng cơ bản hoàn toàn miễn phí.',
    detailPath: '/pricing',
    ctaLabel: 'Xem chi tiết các gói dịch vụ',
  ),
  HomeFaqItem(
    id: 'safety',
    question: 'Làm sao để tránh lừa đảo khi tìm phòng?',
    shortAnswer:
        'Luôn kiểm tra tin đăng đã kiểm duyệt, chủ trọ đã xác minh và không chuyển khoản trước khi xem phòng.',
    detailPath: '/faq',
    ctaLabel: 'Đọc hướng dẫn an toàn',
  ),
  HomeFaqItem(
    id: 'roommate',
    question: 'Ghép roommate trên SacoStay hoạt động thế nào?',
    shortAnswer:
        'Làm lifestyle quiz, swipe discovery để tìm người có gu tương đồng, sau đó chat và kết nối.',
    detailPath: '/discovery',
    ctaLabel: 'Khám phá discovery',
  ),
];
