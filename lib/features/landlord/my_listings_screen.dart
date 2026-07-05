import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/utils/listing_display.dart';
import '../../core/utils/vip_tier.dart';
import '../../models/room_post.dart';
import '../../repositories/room_post_repository.dart';
import '../../shared/widgets/saco_landlord_ui.dart';
import 'widgets/listing_adjust_sheets.dart';

final myListingsProvider = FutureProvider.autoDispose<List<RoomPostSummary>>((ref) {
  return ref.watch(roomPostRepositoryProvider).getMyPosts();
});

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  String? _busyId;

  Future<void> _refresh() async => ref.invalidate(myListingsProvider);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myListingsProvider);
    final priceFmt = NumberFormat('#,###', 'vi_VN');

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (posts) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SacoPageHeader(
                      title: 'Tin đã đăng',
                      subtitle: 'Quản lý trạng thái và nâng cấp VIP cho từng tin',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SacoPrimaryButton(
                        label: 'Đăng tin mới',
                        fullWidth: true,
                        onPressed: () => context.go('/create-listing'),
                      ),
                    ),
                  ],
                ),
              ),
              if (posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Chưa có tin đăng nào'),
                        const SizedBox(height: 16),
                        SacoPrimaryButton(
                          label: 'Đăng tin đầu tiên',
                          onPressed: () => context.go('/create-listing'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _ListingCard(
                        post: post,
                        priceLabel: post.price != null
                            ? '${priceFmt.format(post.price)} đ/tháng'
                            : '—',
                        busy: _busyId == post.id,
                        onOpenDetail: () => context.go(
                          Uri(
                            path: '/rooms/${post.id}',
                            queryParameters: const {'from': 'my-listings'},
                          ).toString(),
                        ),
                        onAdjust: () => _showEditDialog(post),
                        onPay: () => context.go(
                          Uri(
                            path: '/landlord-pricing',
                            queryParameters: {'postId': post.id},
                          ).toString(),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(RoomPostSummary post) async {
    final saved = await showListingEditDialog(
      context: context,
      post: post,
      repository: ref.read(roomPostRepositoryProvider),
    );
    if (saved) await _refresh();
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.post,
    required this.priceLabel,
    required this.busy,
    required this.onOpenDetail,
    required this.onAdjust,
    required this.onPay,
  });

  final RoomPostSummary post;
  final String priceLabel;
  final bool busy;
  final VoidCallback onOpenDetail;
  final VoidCallback onAdjust;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final showAdjust = isListingActive(post.status);
    final showPay = isListingPendingPayment(post.status);
    final showActions = showAdjust || showPay;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: post.imageUrl != null
                      ? Image.network(
                          post.imageUrl!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: vipTierTitleStyle(post.vipTier, compact: true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          vipTierBadge(post.vipTier),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.address ?? post.city ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        priceLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: vipTierPriceBadgeColor(post.vipTier),
                          fontSize: 15,
                        ),
                      ),
                      if (post.maxPeople != null)
                        Text(
                          'Đang ở: ${post.currentPeople ?? 0}/${post.maxPeople} người',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 8),
                      listingStatusChip(post.status),
                    ],
                  ),
                ),
                if (showActions) ...[
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else ...[
                        if (showPay)
                          FilledButton(
                            onPressed: () {
                              onPay();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: SacoColors.sacoOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Thanh toán', style: TextStyle(fontSize: 13)),
                          ),
                        if (showAdjust) ...[
                          if (showPay) const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              onAdjust();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SacoColors.sacoBlue,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Điều chỉnh', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 88,
      height: 88,
      color: Colors.grey.shade200,
      child: Icon(Icons.home_outlined, color: Colors.grey.shade400),
    );
  }
}
