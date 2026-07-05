import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/admin_models.dart';
import '../../repositories/admin_repository.dart';
import '../../shared/widgets/saco_landlord_ui.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(_dashboardProvider);
    final pendingCount = dashAsync.value?.pendingListings ?? 0;
    final reportCount = dashAsync.value?.openReports ?? 0;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_dashboardProvider);
              ref.invalidate(_usersProvider);
              ref.invalidate(_listingsProvider('Pending'));
              ref.invalidate(_reportsProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SacoGradientBanner(
                    eyebrow: 'SACOSTAY ADMIN',
                    title: 'Dashboard Quản trị',
                    subtitle:
                        'Theo dõi tăng trưởng người dùng, tin phòng và báo cáo — dữ liệu đồng bộ từ API Admin & Report.',
                    action: OutlinedButton(
                      onPressed: () {
                        ref.invalidate(_dashboardProvider);
                        ref.invalidate(_usersProvider);
                        ref.invalidate(_listingsProvider('Pending'));
                        ref.invalidate(_reportsProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      child: const Text('Làm mới dữ liệu'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SacoPillTabs(
                    tabs: [
                      'Tổng quan',
                      'Tin chờ duyệt ($pendingCount)',
                      'Người dùng',
                      'Báo cáo ($reportCount)',
                    ],
                    selectedIndex: _tab,
                    onSelected: (i) => setState(() => _tab = i),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Cuộn xuống để duyệt tin và quản lý người dùng — hoặc chọn tab bên trên.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildTabContent()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 1:
        return const _ListingsApprovalSection();
      case 2:
        return const _UsersSection();
      case 3:
        return const _ReportsSection();
      default:
        return const _OverviewSection();
    }
  }
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashboardProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Lỗi: $e'),
      ),
      data: (stats) {
        final cards = [
          _StatCardData(
            icon: Icons.people_alt_outlined,
            iconColor: const Color(0xFF8B5CF6),
            label: 'Tổng người dùng',
            value: '${stats.totalUsers}',
            delta: '+10%',
            deltaUp: true,
          ),
          _StatCardData(
            icon: Icons.home_work_outlined,
            iconColor: const Color(0xFFEF4444),
            label: 'Tổng tin phòng',
            value: '${stats.totalListings}',
            delta: stats.totalListings > 0 ? '—' : '0',
            deltaUp: false,
          ),
          _StatCardData(
            icon: Icons.pending_actions_outlined,
            iconColor: const Color(0xFF2563EB),
            label: 'Tin chờ duyệt',
            value: '${stats.pendingListings}',
            delta: 'Cần xử lý',
            deltaUp: stats.pendingListings == 0,
          ),
          _StatCardData(
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFFF59E0B),
            label: 'Báo cáo mở',
            value: '${stats.openReports}',
            delta: '30 ngày gần nhất',
            deltaUp: stats.openReports == 0,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SacoHorizontalScroll(
                minWidth: cards.length * 260.0,
                child: Row(
                  children: cards
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _AdminStatCard(data: c),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const _ListingsApprovalSection(compact: true),
          ],
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaUp,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String delta;
  final bool deltaUp;
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.iconColor, size: 22),
              const Spacer(),
              Text(
                data.delta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: data.deltaUp ? Colors.green : Colors.red.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: SacoColors.sacoBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '30 ngày gần nhất',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _ListingsApprovalSection extends ConsumerStatefulWidget {
  const _ListingsApprovalSection({this.compact = false});

  final bool compact;

  @override
  ConsumerState<_ListingsApprovalSection> createState() =>
      _ListingsApprovalSectionState();
}

class _ListingsApprovalSectionState extends ConsumerState<_ListingsApprovalSection> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_listingsProvider('Pending'));

    return SacoSectionCard(
      title: 'Phòng trọ — duyệt tin',
      subtitle: 'Duyệt tin để chuyển sang trạng thái Active (hiển thị công khai).',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Lỗi: $e'),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Không có tin chờ duyệt.'),
            );
          }
          final show = widget.compact ? items.take(3).toList() : items;
          return SacoHorizontalScroll(
            minWidth: 680,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(280),
                1: FixedColumnWidth(200),
                2: FixedColumnWidth(120),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: const [
                    _TableHead('Phòng trọ'),
                    _TableHead('Chủ trọ'),
                    _TableHead('Thao tác'),
                  ],
                ),
                ...show.map((post) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.landlordName ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (post.city != null)
                              Text(
                                post.city!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Duyệt',
                              icon: const Icon(Icons.check_circle_outline,
                                  color: Colors.green),
                              onPressed: () => _approve(post.id),
                            ),
                            IconButton(
                              tooltip: 'Từ chối',
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Colors.red),
                              onPressed: () => _reject(post.id),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(String id) async {
    await ref.read(adminRepositoryProvider).approveListing(id);
    ref.invalidate(_listingsProvider('Pending'));
    ref.invalidate(_dashboardProvider);
  }

  Future<void> _reject(String id) async {
    await ref.read(adminRepositoryProvider).rejectListing(id);
    ref.invalidate(_listingsProvider('Pending'));
    ref.invalidate(_dashboardProvider);
  }
}

class _UsersSection extends ConsumerWidget {
  const _UsersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_usersProvider);
    return SacoSectionCard(
      title: 'Người dùng',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Lỗi: $e'),
        data: (users) {
          if (users.isEmpty) return const Text('Không có dữ liệu.');
          return SacoHorizontalScroll(
            minWidth: 620,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(180),
                1: FixedColumnWidth(220),
                2: FixedColumnWidth(160),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: const [
                    _TableHead('Tên'),
                    _TableHead('Email'),
                    _TableHead('Vai trò'),
                  ],
                ),
                ...users.map(
                  (u) => TableRow(
                    children: [
                      _TableBody(u.displayName),
                      _TableBody(u.email ?? '—'),
                      _TableBody(u.roles.join(', ')),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportsSection extends ConsumerStatefulWidget {
  const _ReportsSection();

  @override
  ConsumerState<_ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends ConsumerState<_ReportsSection> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_reportsProvider);
    return SacoSectionCard(
      title: 'Báo cáo người dùng',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Lỗi: $e'),
        data: (reports) {
          if (reports.isEmpty) return const Text('Không có báo cáo.');
          return SacoHorizontalScroll(
            minWidth: 640,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(200),
                1: FixedColumnWidth(160),
                2: FixedColumnWidth(160),
                3: FixedColumnWidth(100),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: const [
                    _TableHead('Lý do'),
                    _TableHead('Người báo cáo'),
                    _TableHead('Đối tượng'),
                    _TableHead('Xử lý'),
                  ],
                ),
                ...reports.map(
                  (r) => TableRow(
                    children: [
                      _TableBody(r.reason.isNotEmpty ? r.reason : '—'),
                      _TableBody(r.reporterName ?? '—'),
                      _TableBody(r.targetLabel ?? '—'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: PopupMenuButton<String>(
                          onSelected: (a) => _process(r.id, a == 'valid'),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'valid', child: Text('Hợp lệ')),
                            PopupMenuItem(value: 'invalid', child: Text('Không hợp lệ')),
                          ],
                          child: const Icon(Icons.more_horiz),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _process(String id, bool isValid) async {
    await ref.read(adminRepositoryProvider).processReport(id: id, isValid: isValid);
    ref.invalidate(_reportsProvider);
    ref.invalidate(_dashboardProvider);
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _TableBody extends StatelessWidget {
  const _TableBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}

final _dashboardProvider =
    FutureProvider.autoDispose<AdminDashboardStats>((ref) {
  return ref.watch(adminRepositoryProvider).getDashboard();
});

final _usersProvider = FutureProvider.autoDispose<List<AdminUserRow>>((ref) {
  return ref.watch(adminRepositoryProvider).getUsers();
});

final _listingsProvider =
    FutureProvider.autoDispose.family<List<AdminListingRow>, String>((ref, status) {
  return ref.watch(adminRepositoryProvider).getRoomPosts(status: status);
});

final _reportsProvider = FutureProvider.autoDispose<List<AdminReportRow>>((ref) {
  return ref.watch(adminRepositoryProvider).getReports();
});
