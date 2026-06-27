import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/lifestyle.dart';
import '../../models/tenant_room_profile.dart';
import '../../repositories/lifestyle_repository.dart';
import '../../repositories/tenant_room_repository.dart';
import '../discovery/widgets/tenant_room_details_view.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, this.userId});

  /// `me` or empty = own profile.
  final String? userId;

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
      final answers = await ref.read(lifestyleRepositoryProvider).getMyAnswers();
      final hasRoom = hasRoomFromAnswers(answers);
      TenantRoomProfile? room;
      if (hasRoom) {
        final uid = userIdFromUser(user);
        if (uid != null) {
          room = await ref.read(tenantRoomRepositoryProvider).getByUserId(uid);
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
          _profileCard(context),
          const SizedBox(height: 16),
          _introCard(),
          if (!_isOwn && _compatibility > 0) ...[
            const SizedBox(height: 16),
            _compatibilityCard(),
          ],
          const SizedBox(height: 16),
          _lifestyleCard(),
          if (_hasRoom) ...[
            const SizedBox(height: 16),
            _roomCard(),
          ],
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
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
      child: Column(
        children: [
          CircleAvatar(radius: 56, backgroundImage: NetworkImage(_avatarUrl)),
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
          if (_isOwn) ...[
            OutlinedButton.icon(
              onPressed: () => context.go('/profile-setup'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Thay đổi hồ sơ'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/lifestyle-quiz?retake=1&returnUrl=/profile/me'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SacoColors.sacoOrange,
                side: const BorderSide(color: SacoColors.sacoOrange),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thay đổi lối sống'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/profile-setup'),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Đăng ảnh cá nhân'),
            ),
          ] else ...[
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
          if (_answers.isEmpty)
            Text(
              _isOwn
                  ? 'Chưa có dữ liệu trắc nghiệm.'
                  : 'Người dùng chưa hoàn thành trắc nghiệm lối sống.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ..._answers.map((a) {
              final match = !_isOwn && _isAnswerMatch(a);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: match ? Colors.green.shade50 : SacoColors.pageBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: match ? Colors.green.shade200 : Colors.orange.shade100,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.questionContent,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SacoColors.sacoOrange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(a.optionContent, style: const TextStyle(fontSize: 14)),
                    if (match)
                      Text(
                        'Trùng khớp',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _roomCard() {
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
              const Text('Tình trạng phòng', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SacoColors.sacoOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Đã có phòng trọ',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_tenantRoom != null)
            TenantRoomDetailsView(
              profile: _tenantRoom,
              priceLabel: tenantRoomPriceLabel(_tenantRoom?.price),
            ),
        ],
      ),
    );
  }
}
