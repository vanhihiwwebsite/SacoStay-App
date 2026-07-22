import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/widgets/legal_mobile_widgets.dart';
import '../../shared/widgets/tenant_sub_page_scaffold.dart';
import 'faq_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            const LegalMobileHeader(
              badge: 'Pháp lý · SacoStay',
              title: 'Điều khoản & Chính sách',
              subtitle: 'Quy định sử dụng nền tảng và cam kết bảo mật thông tin người dùng.',
              icon: Icons.gavel_outlined,
              footer: 'Cập nhật lần cuối: 20/05/2026',
            )
          else
            const LegalHero(
              badge: 'Pháp lý · SacoStay',
              title: 'Chính sách bảo mật và Điều khoản sử dụng',
              subtitle: 'Vui lòng đọc kỹ trước khi đăng ký, đăng nhập hoặc sử dụng nền tảng SacoStay.',
              footer: 'Cập nhật lần cuối: 20/05/2026',
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, isMobile ? 0 : 0, 16, 24),
            child: Column(
              children: [
                LegalInfoCard(
                  icon: Icons.info_outline,
                  iconColor: SacoColors.sacoBlue,
                  child: _sectionBody(
                    '1. Giới thiệu',
                    [
                      'SacoStay là nền tảng kết nối người thuê trọ, người tìm bạn ở ghép và chủ trọ.',
                      'Việc sử dụng SacoStay đồng nghĩa với việc bạn đồng ý tuân thủ các điều khoản dưới đây.',
                    ],
                  ),
                ),
                const LegalPartDivider(label: 'CHÍNH SÁCH BẢO MẬT'),
                LegalInfoCard(
                  icon: Icons.security_outlined,
                  iconColor: const Color(0xFF10B981),
                  child: _sectionBody(
                    '2. Mục đích thu thập thông tin',
                    [
                      'SacoStay có thể thu thập họ tên, email, số điện thoại, giới tính, năm sinh, nghề nghiệp, ảnh đại diện và thông tin lối sống.',
                    ],
                    list: [
                      'Tạo và quản lý tài khoản người dùng',
                      'Kết nối người thuê với bạn ở ghép phù hợp',
                      'Hiển thị kết quả tìm kiếm phòng trọ',
                      'Hỗ trợ xác thực tài khoản và liên hệ hỗ trợ',
                    ],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.lock_outline,
                  iconColor: const Color(0xFF6366F1),
                  child: _sectionBody(
                    '3. Phạm vi sử dụng thông tin',
                    ['Thông tin được dùng để cung cấp chức năng nền tảng, tính mức tương hợp và gửi thông báo.'],
                    list: [
                      'SacoStay không bán hoặc chia sẻ thông tin cá nhân cho bên thứ ba khi chưa có sự đồng ý.',
                    ],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.manage_accounts_outlined,
                  iconColor: SacoColors.sacoOrange,
                  child: _sectionBody(
                    '5. Quyền của người dùng',
                    null,
                    list: [
                      'Xem và chỉnh sửa thông tin cá nhân',
                      'Thay đổi mật khẩu',
                      'Yêu cầu xóa tài khoản',
                      'Yêu cầu hỗ trợ về dữ liệu cá nhân',
                    ],
                  ),
                ),
                const LegalPartDivider(label: 'ĐIỀU KHOẢN SỬ DỤNG'),
                LegalInfoCard(
                  icon: Icons.person_outline,
                  iconColor: SacoColors.sacoBlue,
                  child: _sectionBody(
                    '7. Quy định tài khoản',
                    ['Người dùng không được cung cấp thông tin giả mạo hoặc tạo nhiều tài khoản gian lận.'],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.home_work_outlined,
                  iconColor: const Color(0xFF0EA5E9),
                  child: _sectionBody(
                    '8. Quy định đăng tin phòng trọ',
                    ['Chủ trọ phải cung cấp thông tin chính xác. Nghiêm cấm đăng tin giả hoặc lừa đảo.'],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.people_outline,
                  iconColor: const Color(0xFFEC4899),
                  child: _sectionBody(
                    '9. Quy định về tìm bạn ở ghép',
                    ['Người dùng phải khai báo trung thực, tôn trọng người khác và không quấy rối.'],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.chat_bubble_outline,
                  iconColor: const Color(0xFF8B5CF6),
                  child: _sectionBody(
                    '10. Quy định về nhắn tin',
                    ['Không gửi spam, quấy rối, chia sẻ nội dung vi phạm pháp luật hoặc lừa đảo.'],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.balance_outlined,
                  iconColor: const Color(0xFF64748B),
                  child: _sectionBody(
                    '11. Giới hạn trách nhiệm',
                    [
                      'SacoStay là nền tảng kết nối, không tham gia trực tiếp vào hợp đồng thuê.',
                      'Người dùng tự chịu trách nhiệm xác minh thông tin trước khi giao dịch.',
                    ],
                  ),
                ),
                LegalInfoCard(
                  icon: Icons.support_agent_outlined,
                  iconColor: const Color(0xFF10B981),
                  child: _sectionBody(
                    '12. Khiếu nại và hỗ trợ',
                    ['Email: sacostay79@gmail.com — Mọi phản hồi sẽ được tiếp nhận và xử lý.'],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/profile/me'),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Quay lại Cá nhân'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return TenantSubPageScaffold(
        title: 'Điều khoản & chính sách',
        fallbackRoute: '/profile/me',
        body: content,
      );
    }
    return content;
  }

  Widget _sectionBody(String title, List<String>? paragraphs, {List<String>? list}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (paragraphs != null)
          ...paragraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p, style: TextStyle(color: Colors.grey.shade700, height: 1.55, fontSize: 14)),
            ),
          ),
        if (list != null)
          ...list.map(
            (l) => Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: SacoColors.sacoOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l, style: TextStyle(color: Colors.grey.shade700, height: 1.45, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
