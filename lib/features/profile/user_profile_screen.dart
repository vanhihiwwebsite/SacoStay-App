import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../config/brand_social.dart';
import '../../config/theme.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/lifestyle.dart';
import '../../models/tenant_room_profile.dart';
import '../../repositories/lifestyle_repository.dart';
import '../../repositories/tenant_room_repository.dart';
import '../../shared/widgets/landlord_shell.dart';
import '../../shared/widgets/profile_photos_modal.dart';
import '../../shared/widgets/report_modal.dart';
import '../../shared/widgets/tenant_shell.dart';
import '../../shared/widgets/tenant_sub_page_scaffold.dart';
import '../discovery/widgets/tenant_room_details_view.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, this.userId, this.detailOnly = false});

  /// `me` or empty = own profile.
  final String? userId;
  final bool detailOnly;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _loading = true;
  bool _notFound = false;
  bool _isOwn = false;

  Map<String, dynamic>? _user;
  List<UserLifestyleAnswer> _answers = [];
  List<UserLifestyleAnswer> _myAnswers = [];
  int _compatibility = 0;
  bool _hasRoom = false;
  TenantRoomProfile? _tenantRoom;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }

    final param = widget.userId?.trim() ?? '';
    _isOwn = param.isEmpty || param == 'me';

    if (_isOwn) {
      await ref.read(authControllerProvider.notifier).refreshProfile();
      final user = ref.read(authControllerProvider).user?.raw;
      if (user == null || !hasBasicProfileFilled(user)) {
        if (mounted) context.go('/profile-setup');
        return;
      }
      final isLandlord = ref.read(authControllerProvider).userRole == 'landlord';
      List<UserLifestyleAnswer> answers = [];
      TenantRoomProfile? room;
      var hasRoom = false;
      if (!isLandlord) {
        answers = await ref.read(lifestyleRepositoryProvider).getMyAnswers();
        hasRoom = hasRoomFromAnswers(answers);
        if (hasRoom) {
          final uid = userIdFromUser(user);
          if (uid != null) {
            room = await ref.read(tenantRoomRepositoryProvider).getByUserId(uid);
          }
        }
      }
      setState(() {
        _user = user;
        _answers = answers;
        _myAnswers = answers;
        _hasRoom = hasRoom;
        _tenantRoom = room;
        _loading = false;
      });
      return;
    }

    final quota = await ref.read(lifestyleRepositoryProvider).getSwipeQuota();
    if (!quota.isPremium) {
      if (mounted) context.go('/tenant-pricing');
      return;
    }

    try {
      final response = await ref.read(apiClientProvider).dio.get<dynamic>(
        '/Auth/user/${Uri.encodeComponent(param)}',
      );
      if (response.data is! Map) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final user = normalizeAuthUser(Map<String, dynamic>.from(response.data as Map));
      final answers = await ref.read(lifestyleRepositoryProvider).getUserAnswers(param);
      final score = await ref.read(lifestyleRepositoryProvider).getMatchingScore(param);
      final hasRoom = hasRoomFromAnswers(answers);
      TenantRoomProfile? room;
      if (hasRoom) {
        room = await ref.read(tenantRoomRepositoryProvider).getByUserId(param);
      }
      final myAnswers = await ref.read(lifestyleRepositoryProvider).getMyAnswers();
      setState(() {
        _user = user;
        _answers = answers;
        _myAnswers = myAnswers;
        _compatibility = score;
        _hasRoom = hasRoom;
        _tenantRoom = room;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  String get _displayName => navProfileLabel(_user);
  String get _avatarUrl => resolveUserAvatarUrl(_user, displayName: _displayName);
  String get _bio => _user != null ? strField(pickField(_user!, 'bio', ['Bio'])) : '';
  String get _job => jobLabelVi(_user != null ? strField(pickField(_user!, 'job', ['Job', 'Occupation'])) : '');
  String get _location => profileLivingAreaSeed(_user);
  int? get _age => ageFromDateOfBirth(profileDateOfBirthSeed(_user));
  String get _genderLabel => genderLabelVi(_user?['gender'] ?? _user?['Gender']);

  bool _isAnswerMatch(UserLifestyleAnswer a) {
    for (final m in _myAnswers) {
      if (m.questionId == a.questionId && m.optionId == a.optionId) return true;
    }
    return false;
  }

  static const _lifestyleFromProfileUrl =
      '/lifestyle-quiz?retake=1&returnUrl=%2Fprofile%2Fme';

  Future<void> _openProfileSetup() async {
    await context.push('/profile-setup');
    if (mounted) await _load();
  }

  Future<void> _openLifestyleQuiz() async {
    await context.push(_lifestyleFromProfileUrl);
    if (mounted) await _load();
  }

  double _mobileProfileBottomInset(BuildContext context, bool isLandlord) {
    if (MediaQuery.sizeOf(context).width >= 640) return 0;
    if (isLandlord) return LandlordShell.bottomInset(context);
    return TenantShell.bottomInset(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isLoggedIn) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/login?returnUrl=/profile/me'),
          child: const Text('Đăng nhập để xem hồ sơ'),
        ),
      );
    }

    final isLandlord = _isOwn
        ? auth.userRole == 'landlord'
        : isLandlordUser(_user);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notFound) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không tìm thấy người dùng này.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.pop(), child: const Text('Quay lại')),
          ],
        ),
      );
    }

    final isMobileOwn = _isOwn && MediaQuery.sizeOf(context).width < 640;
    if (isMobileOwn && widget.detailOnly) {
      return _buildMobileProfileDetail(context, isLandlord: isLandlord);
    }
    if (isMobileOwn) {
      return _buildMobileOwnProfile(context, isLandlord: isLandlord);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isOwn)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Quay lại danh sách'),
              ),
            ),
          _profileCard(context, isLandlord: isLandlord),
          const SizedBox(height: 16),
          _introCard(),
          if (!_isOwn && _compatibility > 0 && !isLandlord) ...[
            const SizedBox(height: 16),
            _compatibilityCard(),
          ],
          if (!isLandlord) ...[
            const SizedBox(height: 16),
            _lifestyleCard(),
            const SizedBox(height: 16),
            _roomCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileOwnProfile(BuildContext context, {required bool isLandlord}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SacoColors.sacoOrange,
                  SacoColors.sacoOrange.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _mobileProfileSummaryCard(context),
                  const SizedBox(height: 12),
                  _profileMenuCard(
                    items: isLandlord
                        ? [
                            _ProfileMenuItem(
                              icon: Icons.edit_outlined,
                              iconColor: SacoColors.sacoBlue,
                              label: 'Thay đổi hồ sơ',
                              onTap: _openProfileSetup,
                            ),
                            _ProfileMenuItem(
                              icon: Icons.visibility_outlined,
                              iconColor: const Color(0xFF0EA5E9),
                              label: 'Lượt xem tin',
                              onTap: () => context.go('/listing-viewers'),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.list_alt_outlined,
                              iconColor: SacoColors.sacoOrange,
                              label: 'Danh sách phòng trọ',
                              onTap: () => context.go('/rooms'),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.share_outlined,
                              iconColor: const Color(0xFF6366F1),
                              label: 'Phương tiện truyền thông',
                              onTap: () => _showSocialSheet(context),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.description_outlined,
                              iconColor: const Color(0xFF64748B),
                              label: 'Điều khoản & chính sách',
                              onTap: () => context.go('/terms'),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.help_outline,
                              iconColor: const Color(0xFF0EA5E9),
                              label: 'FAQ',
                              onTap: () => context.go('/faq'),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.contact_mail_outlined,
                              iconColor: const Color(0xFF10B981),
                              label: 'Thông tin liên hệ',
                              onTap: () => _showContactSheet(context),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.logout,
                              iconColor: Colors.red.shade400,
                              label: 'Đăng xuất',
                              onTap: () => ref.read(authControllerProvider.notifier).logout(),
                              showChevron: false,
                            ),
                          ]
                        : [
                            _ProfileMenuItem(
                              icon: Icons.psychology_outlined,
                              iconColor: SacoColors.sacoOrange,
                              label: _answers.isEmpty
                                  ? 'Trắc nghiệm lối sống'
                                  : 'Thay đổi lối sống',
                              onTap: _openLifestyleQuiz,
                            ),
                            _ProfileMenuItem(
                              icon: Icons.edit_outlined,
                              iconColor: SacoColors.sacoBlue,
                              label: 'Thay đổi hồ sơ',
                              onTap: _openProfileSetup,
                            ),
                            _ProfileMenuItem(
                              icon: Icons.photo_library_outlined,
                              iconColor: const Color(0xFF8B5CF6),
                              label: 'Đăng ảnh cá nhân',
                              onTap: () => showProfilePhotosModal(context, ref),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.share_outlined,
                              iconColor: const Color(0xFF6366F1),
                              label: 'Phương tiện truyền thông',
                              onTap: () => _showSocialSheet(context),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.description_outlined,
                              iconColor: const Color(0xFF64748B),
                              label: 'Điều khoản & chính sách',
                              onTap: () => context.go('/terms'),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.help_outline,
                              iconColor: const Color(0xFF0EA5E9),
                              label: 'FAQ',
                              onTap: () => context.go('/faq'),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.contact_mail_outlined,
                              iconColor: const Color(0xFF10B981),
                              label: 'Thông tin liên hệ',
                              onTap: () => _showContactSheet(context),
                            ),
                            _ProfileMenuItem(
                              icon: Icons.logout,
                              iconColor: Colors.red.shade400,
                              label: 'Đăng xuất',
                              onTap: () => ref.read(authControllerProvider.notifier).logout(),
                              showChevron: false,
                            ),
                          ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: _mobileProfileBottomInset(context, isLandlord)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileProfileSummaryCard(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        onTap: () => context.go('/profile/me/detail'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(_avatarUrl),
                  ),
                  if (isVerifiedUser(_user))
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _age != null ? '$_age tuổi • $_genderLabel' : _genderLabel,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (_job.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.work_outline, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(_job, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                  ],
                ),
              ],
              if (_location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _location,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Xem chi tiết hồ sơ',
                    style: TextStyle(
                      color: SacoColors.sacoOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: SacoColors.sacoOrange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileProfileDetail(BuildContext context, {required bool isLandlord}) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _profileCard(context, isLandlord: isLandlord),
          const SizedBox(height: 16),
          _introCard(),
          if (!isLandlord) ...[
            const SizedBox(height: 16),
            _lifestyleCard(),
            const SizedBox(height: 16),
            _roomCard(),
          ],
        ],
      ),
    );

    return TenantSubPageScaffold(
      title: 'Chi tiết hồ sơ',
      body: content,
    );
  }

  Widget _profileMenuCard({required List<_ProfileMenuItem> items}) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ProfileMenuTile(item: items[i]),
            if (i < items.length - 1) Divider(height: 1, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  void _showSocialSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mở bằng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn ứng dụng để mở liên kết',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SocialAppTile(
                    label: 'Facebook',
                    icon: Icons.facebook,
                    color: const Color(0xFF1877F2),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openExternal(BrandSocial.facebookUrl);
                    },
                  ),
                  _SocialAppTile(
                    label: 'TikTok',
                    icon: Icons.music_note_outlined,
                    color: Colors.black87,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openExternal(BrandSocial.tiktokUrl);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thông tin liên hệ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _ContactRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: 'sacostay79@gmail.com',
                onTap: () => _openExternal('mailto:sacostay79@gmail.com'),
              ),
              _ContactRow(
                icon: Icons.phone_outlined,
                label: 'Hotline',
                value: '0366723474',
                onTap: () => _openExternal('tel:0366723474'),
              ),
              const _ContactRow(
                icon: Icons.location_on_outlined,
                label: 'Địa chỉ',
                value: 'Đại học FPT Hồ Chí Minh, Khu Công nghệ cao',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _openExternal(BrandSocial.facebookUrl),
                    icon: const Icon(Icons.facebook),
                  ),
                  IconButton(
                    onPressed: () => _openExternal(BrandSocial.tiktokUrl),
                    icon: const Icon(Icons.music_note_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _profileCard(BuildContext context, {required bool isLandlord}) {
    final targetUserId = userIdFromUser(_user) ?? widget.userId ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!_isOwn && targetUserId.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => showReportModal(
                  context,
                  type: ReportTargetType.user,
                  targetName: _displayName,
                  reportedUserId: targetUserId,
                ),
                icon: Icon(Icons.flag_outlined, size: 20, color: Colors.red.shade400),
                tooltip: 'Báo cáo',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(radius: 56, backgroundImage: NetworkImage(_avatarUrl)),
                  if (isVerifiedUser(_user))
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
          const SizedBox(height: 12),
          Text(
            _displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _age != null ? '$_age tuổi • $_genderLabel' : _genderLabel,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(_job, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
          if (_location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(_location, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_isOwn && MediaQuery.sizeOf(context).width >= 640) ...[
            OutlinedButton.icon(
              onPressed: _openProfileSetup,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Thay đổi hồ sơ'),
            ),
            if (!isLandlord) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openLifestyleQuiz,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SacoColors.sacoOrange,
                  side: const BorderSide(color: SacoColors.sacoOrange),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thay đổi lối sống'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showProfilePhotosModal(context, ref),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Đăng ảnh cá nhân'),
            ),
            if (isLandlord) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/my-listings'),
                icon: const Icon(Icons.view_list_outlined, size: 18),
                label: const Text('Tin đã đăng'),
              ),
            ],
          ] else if (!_isOwn) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final id = userIdFromUser(_user) ?? widget.userId ?? '';
                      context.go(
                        Uri(
                          path: '/chat',
                          queryParameters: {
                            'with': id,
                            'name': _displayName,
                            'avatar': _avatarUrl,
                            'role': 'tenant',
                          },
                        ).toString(),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Nhắn tin'),
                  ),
                ),
              ],
            ),
          ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Giới thiệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _bio.isNotEmpty ? _bio : 'Chưa có giới thiệu.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _compatibilityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Độ hòa hợp lối sống',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Dựa trên trắc nghiệm lối sống của cả hai',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '$_compatibility%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lifestyleCard() {
    final displayAnswers = lifestyleAnswersForDisplay(_answers);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết lối sống', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (displayAnswers.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOwn
                      ? 'Chưa có dữ liệu trắc nghiệm.'
                      : 'Người dùng chưa hoàn thành trắc nghiệm lối sống.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (_isOwn) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _openLifestyleQuiz,
                    style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                    child: const Text('Làm trắc nghiệm'),
                  ),
                ],
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 520;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: displayAnswers.map((a) {
                    final match = !_isOwn && _isAnswerMatch(a);
                    return SizedBox(
                      width: wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: match ? Colors.green.shade50 : const Color(0xFFFFFBF7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: match ? Colors.green.shade200 : Colors.orange.shade100,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: match ? Colors.green.shade500 : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lifestyleAnswerLabel(a),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: SacoColors.sacoOrange,
                                    ),
                                  ),
                                ),
                                if (match)
                                  Text(
                                    'Trùng khớp',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                a.optionContent,
                                style: const TextStyle(fontSize: 14, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _roomCard() {
    final hasRoom = _hasRoom;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_outlined, color: SacoColors.sacoOrange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Tình trạng phòng', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasRoom ? Colors.green.shade100 : Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  roomStatusLabel(hasRoom),
                  style: TextStyle(
                    color: hasRoom ? Colors.green.shade800 : Colors.yellow.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasRoom) ...[
            if (_tenantRoom != null)
              TenantRoomDetailsView(
                profile: _tenantRoom,
                priceLabel: tenantRoomPriceLabel(_tenantRoom?.price),
              )
            else if (_isOwn)
              Text(
                'Chưa có chi tiết phòng trọ. Hãy thêm địa điểm, giá thuê và tiện nghi.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              )
            else
              Text(
                'Người dùng chưa cập nhật chi tiết phòng trọ.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            if (_isOwn) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(
                  '/tenant-room-profile?returnUrl=${Uri.encodeComponent('/profile/me')}',
                ),
                child: Text(
                  _tenantRoom != null ? 'Chỉnh sửa thông tin phòng' : 'Thêm thông tin phòng',
                  style: const TextStyle(
                    color: SacoColors.sacoOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ] else
            Text(
              'Đang tìm kiếm phòng trọ và bạn cùng phòng phù hợp.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem {
  const _ProfileMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({required this.item});

  final _ProfileMenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            if (item.showChevron)
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _SocialAppTile extends StatelessWidget {
  const _SocialAppTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: SacoColors.sacoOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(value, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
