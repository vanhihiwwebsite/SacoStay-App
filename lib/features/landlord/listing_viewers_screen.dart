import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/relative_time.dart';
import '../../core/utils/user_display.dart';
import '../../core/utils/vip_tier.dart';
import '../../features/auth/auth_provider.dart';
import '../../core/utils/listing_display.dart';
import '../../models/lifestyle.dart';
import '../../models/listing_analytics.dart';
import '../../models/room_post.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/lifestyle_repository.dart';
import '../../repositories/room_post_repository.dart';
import '../../repositories/tenant_room_repository.dart';
import 'my_listings_screen.dart';

class ViewerDisplayRow {
  ViewerDisplayRow({
    required this.row,
    required this.displayName,
    required this.avatarUrl,
    required this.viewTimeLabel,
  });

  final ListingViewerRow row;
  String displayName;
  String avatarUrl;
  final String viewTimeLabel;
}

class ListingViewersScreen extends ConsumerStatefulWidget {
  const ListingViewersScreen({super.key, this.initialPostId});

  final String? initialPostId;

  @override
  ConsumerState<ListingViewersScreen> createState() => _ListingViewersScreenState();
}

class _ListingViewersScreenState extends ConsumerState<ListingViewersScreen> {
  static const _allPosts = 'all';

  String _selectedPostId = _allPosts;
  List<ViewerDisplayRow> _viewers = [];
  int _totalViewsIn24H = 0;
  bool _isLimitedView = false;
  String _apiPackage = 'BASIC';
  bool _loadingViewers = false;
  bool _viewersLoaded = false;
  String? _errorMessage;

  ViewerDisplayRow? _selectedViewer;
  bool _viewerProfileLoading = false;
  String? _viewerProfileError;
  Map<String, dynamic>? _viewerUser;
  List<UserLifestyleAnswer> _viewerAnswers = [];
  List<UserLifestyleAnswer> _landlordAnswers = [];
  int? _matchScore;
  bool _viewerHasRoom = false;
  String _viewerRoomPriceLabel = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialPostId != null && widget.initialPostId!.isNotEmpty) {
      _selectedPostId = widget.initialPostId!;
    }
  }

  VipTier get _landlordVip {
    final user = ref.read(authControllerProvider).user?.raw;
    final pkg = pickField(user ?? {}, 'landlordPackage', ['LandlordPackage', 'packageTier']);
    return parseRoomVipTier(pkg);
  }

  Future<void> _loadViewers(List<RoomPostSummary> posts) async {
    if (posts.isEmpty) {
      setState(() => _viewers = []);
      return;
    }
    final ids = _selectedPostId == _allPosts
        ? posts.map((p) => p.id).where((id) => id.isNotEmpty).toList()
        : [_selectedPostId];

    setState(() {
      _loadingViewers = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(roomPostRepositoryProvider);
      final rows = await Future.wait(ids.map(repo.getRoomViewAnalytics));
      final merged = _mergeAnalytics(rows);
      if (!mounted) return;
      setState(() {
        _viewers = merged.viewers;
        _totalViewsIn24H = merged.totalViews;
        _isLimitedView = merged.isLimited;
        _apiPackage = merged.package;
        _loadingViewers = false;
      });
      await _hydrateViewerProfiles();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingViewers = false;
        _errorMessage = 'Không tải được phân tích lượt xem: $e';
      });
    }
  }

  Future<void> _hydrateViewerProfiles() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    for (final v in _viewers) {
      final peer = await chatRepo.fetchPeer(v.row.tenantId);
      if (!mounted) return;
      setState(() {
        v.displayName = peer.displayName;
        v.avatarUrl = peer.avatarUrl ?? avatarFallbackUrl(peer.displayName);
      });
    }
  }

  ({
    List<ViewerDisplayRow> viewers,
    int totalViews,
    bool isLimited,
    String package,
  }) _mergeAnalytics(List<RoomPostViewAnalytics> rows) {
    final allRows = rows.expand((r) => r.viewers).toList();
    final byTenant = <String, ViewerDisplayRow>{};
    for (final v in allRows) {
      final next = ViewerDisplayRow(
        row: v,
        displayName: 'Người dùng',
        avatarUrl: avatarFallbackUrl('U'),
        viewTimeLabel: formatRelativeTimeVi(v.viewedAt),
      );
      final existing = byTenant[v.tenantId];
      if (existing == null) {
        byTenant[v.tenantId] = next;
        continue;
      }
      final existingTime = DateTime.tryParse(existing.row.viewedAt)?.millisecondsSinceEpoch ?? 0;
      final nextTime = DateTime.tryParse(v.viewedAt)?.millisecondsSinceEpoch ?? 0;
      if (nextTime > existingTime) byTenant[v.tenantId] = next;
    }
    final viewers = byTenant.values.toList()
      ..sort((a, b) {
        final at = DateTime.tryParse(a.row.viewedAt)?.millisecondsSinceEpoch ?? 0;
        final bt = DateTime.tryParse(b.row.viewedAt)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
    return (
      viewers: viewers,
      totalViews: rows.fold<int>(0, (s, r) => s + r.totalViewsIn24H),
      isLimited: rows.any((r) => r.isLimitedView),
      package: normalizeLandlordPackageCode(rows.isNotEmpty ? rows.first.currentPackage : 'BASIC'),
    );
  }

  Future<void> _openViewer(ViewerDisplayRow viewer) async {
    setState(() {
      _selectedViewer = viewer;
      _viewerProfileLoading = true;
      _viewerProfileError = null;
      _viewerUser = null;
      _viewerAnswers = [];
      _landlordAnswers = [];
      _matchScore = null;
      _viewerHasRoom = false;
      _viewerRoomPriceLabel = '';
    });

    try {
      final dio = ref.read(apiClientProvider).dio;
      final lifestyle = ref.read(lifestyleRepositoryProvider);
      final tenantRoom = ref.read(tenantRoomRepositoryProvider);
      final tenantId = viewer.row.tenantId;

      final response = await dio.get<dynamic>('/Auth/user/${Uri.encodeComponent(tenantId)}');
      if (response.data is! Map) {
        setState(() {
          _viewerProfileError = 'Không tải được hồ sơ người xem.';
          _viewerProfileLoading = false;
        });
        return;
      }

      final user = normalizeAuthUser(Map<String, dynamic>.from(response.data as Map));
      final answers = await lifestyle.getUserAnswers(tenantId);
      final score = await lifestyle.getMatchingScore(tenantId);
      final myAnswers = await lifestyle.getMyAnswers();
      final hasRoom = hasRoomFromAnswers(answers);
      String priceLabel = '';
      if (hasRoom) {
        final profile = await tenantRoom.getByUserId(tenantId);
        priceLabel = tenantRoomPriceLabel(profile?.price);
      }

      final name = navProfileLabel(user);
      final avatar = profileAvatarFromRaw(user);
      if (!mounted) return;
      setState(() {
        _viewerUser = user;
        viewer.displayName = name;
        viewer.avatarUrl = (avatar != null && avatar.isNotEmpty)
            ? resolveMediaUrl(avatar)
            : avatarFallbackUrl(name);
        _viewerAnswers = answers;
        _landlordAnswers = myAnswers;
        _matchScore = score;
        _viewerHasRoom = hasRoom;
        _viewerRoomPriceLabel = priceLabel;
        _viewerProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _viewerProfileError = 'Không tải được hồ sơ người xem.';
        _viewerProfileLoading = false;
      });
    }
  }

  void _closeViewer() {
    setState(() {
      _selectedViewer = null;
      _viewerProfileError = null;
    });
  }

  bool _isAnswerMatch(UserLifestyleAnswer a) {
    for (final m in _landlordAnswers) {
      if (m.questionId == a.questionId && m.optionId == a.optionId) return true;
    }
    return false;
  }

  String _chatUrl(ViewerDisplayRow viewer) {
    return Uri(
      path: '/chat',
      queryParameters: {
        'with': viewer.row.tenantId,
        'name': viewer.displayName,
        'role': 'tenant',
        if (viewer.avatarUrl.isNotEmpty) 'avatar': viewer.avatarUrl,
      },
    ).toString();
  }

  String _viewerLimitLabel() {
    if (_isLimitedView) {
      return 'Gói hiện tại: tối đa 5 người xem gần nhất trong 24h';
    }
    return 'Gói ELITE: xem toàn bộ lượt xem trong 24h';
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedViewer != null) {
      return _buildViewerDetail(_selectedViewer!);
    }

    final postsAsync = ref.watch(myListingsProvider);

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (posts) {
        if (!_viewersLoaded && posts.isNotEmpty) {
          _viewersLoaded = true;
          if (_selectedPostId == _allPosts && posts.length == 1) {
            _selectedPostId = posts.first.id;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadViewers(posts));
        }

        return RefreshIndicator(
          onRefresh: () {
            _viewersLoaded = true;
            return _loadViewers(posts);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(posts),
                if (posts.length > 1) _buildPostFilter(posts),
                if (posts.isEmpty) _buildEmptyPosts() else ...[
                  if (_landlordVip == VipTier.free) _buildUpgradeBanner(),
                  if (_landlordVip != VipTier.free && _isLimitedView) _buildLimitedBanner(),
                  if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                  if (_loadingViewers)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _buildViewersTable(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(List<RoomPostSummary> posts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân tích người xem tin',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SacoColors.sacoBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Danh sách khách tiềm năng đã xem phòng của bạn (24h gần nhất)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          if (posts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_viewers.length} người · $_totalViewsIn24H lượt xem (24h)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    _landlordVip == VipTier.free ? 'BASIC' : vipTierLabel(_landlordVip),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostFilter(List<RoomPostSummary> posts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text('Tin đăng:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedPostId,
                items: [
                  const DropdownMenuItem(value: _allPosts, child: Text('Tất cả tin đăng')),
                  ...posts.map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis)),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedPostId = v);
                  _loadViewers(posts);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPosts() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Text('Bạn chưa có tin đăng nào.'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/create-listing'),
            child: const Text('Đăng tin đầu tiên'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.visibility_outlined, color: SacoColors.sacoOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viewerLimitLabel(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      'Nâng cấp gói ELITE trên tin để xem đủ danh sách',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => context.go('/landlord-pricing'),
              style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
              child: const Text('Nâng cấp VIP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        '${_viewerLimitLabel()} · Gói tin: $_apiPackage',
        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
    );
  }

  Widget _buildViewersTable() {
    if (_viewers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              'Chưa có ai xem tin trong 24h qua.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Gợi ý: đăng nhập tài khoản người thuê, mở chi tiết tin trên /rooms để ghi nhận lượt xem.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: _viewers.map((viewer) => _ViewerListTile(
          viewer: viewer,
          onOpenProfile: () => _openViewer(viewer),
          onChat: () => context.go(_chatUrl(viewer)),
        )).toList(),
      ),
    );
  }

  Widget _buildViewerDetail(ViewerDisplayRow viewer) {
    if (_viewerProfileLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Đang tải hồ sơ người xem…'),
      ));
    }
    if (_viewerProfileError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_viewerProfileError!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _closeViewer, child: const Text('Quay lại danh sách')),
          ],
        ),
      );
    }

    final user = _viewerUser;
    final age = ageFromDateOfBirth(profileDateOfBirthSeed(user));
    final gender = genderLabelVi(user?['gender'] ?? user?['Gender']);
    final job = jobLabelVi(strField(pickField(user ?? {}, 'job', ['Job'])));
    final location = profileLivingAreaSeed(user);
    final bio = strField(pickField(user ?? {}, 'bio', ['Bio']));
    final displayAnswers = lifestyleAnswersForDisplay(_viewerAnswers);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: _closeViewer,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Quay lại danh sách'),
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundImage: NetworkImage(viewer.avatarUrl),
                ),
                const SizedBox(height: 12),
                Text(viewer.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (age != null)
                  Text('$age tuổi · $gender', style: TextStyle(color: Colors.grey.shade600))
                else
                  Text(gender, style: TextStyle(color: Colors.grey.shade600)),
                Text(job, style: TextStyle(color: Colors.grey.shade600)),
                if (location.isNotEmpty)
                  Text('📍 $location', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  'Xem tin ${viewer.viewTimeLabel}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go(_chatUrl(viewer)),
                    style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                    child: const Text('Nhắn tin'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Tin đã xem',
            child: Text(viewer.row.roomTitle.isNotEmpty ? viewer.row.roomTitle : '—'),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Tình trạng phòng',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _viewerHasRoom ? Colors.green.shade100 : Colors.yellow.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    roomStatusLabel(_viewerHasRoom),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _viewerHasRoom ? Colors.green.shade800 : Colors.yellow.shade900,
                    ),
                  ),
                ),
                if (_viewerRoomPriceLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Ngân sách: $_viewerRoomPriceLabel'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Giới thiệu',
            child: Text(bio.isNotEmpty ? bio : 'Chưa có giới thiệu.', style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.red.shade50, Colors.white]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Độ hòa hợp lối sống', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(
                        _landlordAnswers.isNotEmpty
                            ? 'So sánh trắc nghiệm của bạn với người xem tin'
                            : 'Hoàn thành trắc nghiệm lối sống để xem chi tiết điểm trùng khớp',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_matchScore ?? 0}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Chi tiết lối sống',
            child: displayAnswers.isEmpty
                ? Text('Người này chưa hoàn thành trắc nghiệm lối sống.', style: TextStyle(color: Colors.grey.shade600))
                : Column(
                    children: displayAnswers.map((a) {
                      final match = _isAnswerMatch(a);
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
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
                                Icon(Icons.circle, size: 8, color: match ? Colors.green : Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    lifestyleCategoryLabel(a.questionContent),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: SacoColors.sacoOrange,
                                    ),
                                  ),
                                ),
                                if (match)
                                  Text('Trùng khớp', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Text(a.optionContent, style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViewerListTile extends StatelessWidget {
  const _ViewerListTile({
    required this.viewer,
    required this.onOpenProfile,
    required this.onChat,
  });

  final ViewerDisplayRow viewer;
  final VoidCallback onOpenProfile;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onOpenProfile,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(viewer.avatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(viewer.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          'Người thuê đã đăng nhập',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                viewer.row.roomTitle.isNotEmpty ? viewer.row.roomTitle : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(viewer.viewTimeLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onOpenProfile,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Hồ sơ', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onChat,
                    style: FilledButton.styleFrom(
                      backgroundColor: SacoColors.sacoOrange,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Liên hệ', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
