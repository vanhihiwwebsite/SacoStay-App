import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import 'faq_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LegalHero(
            badge: 'Pháp lý · SacoStay',
            title: 'Chính sách bảo mật và Điều khoản sử dụng',
            subtitle: 'Vui lòng đọc kỹ trước khi đăng ký, đăng nhập hoặc sử dụng nền tảng SacoStay.',
            footer: 'Cập nhật lần cuối: 20/05/2026',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    '1. Giới thiệu',
                    [
                      'SacoStay là nền tảng kết nối người thuê trọ, người tìm bạn ở ghép và chủ trọ thông qua hệ thống tìm kiếm phòng trọ, ghép đôi người dùng theo lối sống và các công cụ hỗ trợ liên lạc trực tuyến.',
                      'Việc sử dụng SacoStay đồng nghĩa với việc người dùng đồng ý tuân thủ các điều khoản và chính sách được quy định dưới đây.',
                    ],
                  ),
                  _partTitle('CHÍNH SÁCH BẢO MẬT'),
                  _section(
                    '2. Mục đích thu thập thông tin',
                    [
                      'SacoStay có thể thu thập: họ tên, email, số điện thoại, giới tính, năm sinh, nghề nghiệp, hình ảnh đại diện, thông tin xác thực tài khoản và thông tin về lối sống, nhu cầu ở ghép.',
                    ],
                    list: [
                      'Tạo và quản lý tài khoản người dùng',
                      'Kết nối người thuê với bạn ở ghép phù hợp',
                      'Hiển thị kết quả tìm kiếm phòng trọ',
                      'Hỗ trợ xác thực tài khoản và liên hệ hỗ trợ',
                    ],
                  ),
                  _section(
                    '3. Phạm vi sử dụng thông tin',
                    ['Thông tin người dùng được sử dụng để cung cấp chức năng nền tảng, tính toán mức độ tương hợp, gửi thông báo và xử lý phản hồi.'],
                    list: [
                      'SacoStay không bán hoặc chia sẻ thông tin cá nhân cho bên thứ ba phục vụ quảng cáo khi chưa có sự đồng ý.',
                    ],
                  ),
                  _section(
                    '5. Quyền của người dùng',
                    null,
                    list: [
                      'Xem và chỉnh sửa thông tin cá nhân',
                      'Thay đổi mật khẩu',
                      'Yêu cầu xóa tài khoản',
                      'Yêu cầu hỗ trợ về dữ liệu cá nhân',
                    ],
                  ),
                  _partTitle('ĐIỀU KHOẢN SỬ DỤNG'),
                  _section(
                    '7. Quy định tài khoản',
                    ['Người dùng không được cung cấp thông tin giả mạo, mạo danh hoặc tạo nhiều tài khoản gian lận.'],
                  ),
                  _section(
                    '8. Quy định đăng tin phòng trọ',
                    ['Chủ trọ phải cung cấp thông tin chính nghiệp và chịu trách nhiệm nội dung đăng tải. Nghiêm cấm đăng tin giả hoặc lừa đảo.'],
                  ),
                  _section(
                    '9. Quy định về tìm bạn ở ghép',
                    ['Người dùng phải khai báo trung thực, tôn trọng người khác và không quấy rối.'],
                  ),
                  _section(
                    '10. Quy định về nhắn tin',
                    ['Không gửi spam, quấy rối, chia sẻ nội dung vi phạm pháp luật hoặc lừa đảo.'],
                  ),
                  _section(
                    '11. Giới hạn trách nhiệm',
                    [
                      'SacoStay là nền tảng kết nối giữa các bên, không tham gia trực tiếp vào hợp đồng thuê hoặc thỏa thuận ở ghép.',
                      'Người dùng tự chịu trách nhiệm xác minh thông tin và đưa ra quyết định giao dịch.',
                    ],
                  ),
                  _section(
                    '12. Khiếu nại và hỗ trợ',
                    ['Email: sacostay79@gmail.com — Mọi phản hồi sẽ được tiếp nhận và xử lý theo quy trình hỗ trợ.'],
                  ),
                  _section(
                    '13. Thay đổi điều khoản',
                    [
                      'SacoStay có quyền cập nhật điều khoản để phù hợp với hoạt động nền tảng và quy định pháp luật.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Về trang chủ'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: SacoColors.sacoOrange,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _section(String title, List<String>? paragraphs, {List<String>? list}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (paragraphs != null)
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(p, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
              ),
            ),
          if (list != null)
            ...list.map(
              (l) => Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(l, style: TextStyle(color: Colors.grey.shade700))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
