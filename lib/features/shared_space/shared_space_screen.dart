import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/shared_space.dart';
import '../../repositories/shared_space_repository.dart';

class SharedSpaceScreen extends ConsumerStatefulWidget {
  const SharedSpaceScreen({super.key, this.spaceId});

  final String? spaceId;

  @override
  ConsumerState<SharedSpaceScreen> createState() => _SharedSpaceScreenState();
}

class _SharedSpaceScreenState extends ConsumerState<SharedSpaceScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  SharedSpaceCurrent? _space;
  bool _notFound = false;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _loadSpace();
  }

  Future<void> _loadSpace() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(sharedSpaceRepositoryProvider);
      final space = widget.spaceId != null && widget.spaceId!.isNotEmpty
          ? await repo.getSpaceById(widget.spaceId!)
          : await repo.getCurrentSpace();
      if (!mounted) return;
      setState(() {
        _space = space;
        _notFound = space == null;
        _loading = false;
        _showCelebration = space?.status == 'Finalized';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  bool get _isActive => _space?.status == 'Active';
  bool get _isPendingFinalize => _space?.status == 'PendingFinalize';
  bool get _isFinalized => _space?.status == 'Finalized';

  bool get _isProposer {
    final space = _space;
    if (space?.finalizeRequestedByUserId == null) return false;
    return space!.finalizeRequestedByUserId == space.myId;
  }

  bool get _isApprover => _isPendingFinalize && !_isProposer;

  SharedSpaceShortlistItem? get _proposedRoom {
    final space = _space;
    if (space?.finalizedRoomId == null) return null;
    for (final item in space!.shortlist) {
      if (item.roomId == space.finalizedRoomId) return item;
    }
    return null;
  }

  String _formatPrice(int price) {
    if (price <= 0) return 'Liên hệ';
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(price);
  }

  String _voteLabel(String vote) {
    if (vote == 'Like') return 'Thích';
    if (vote == 'Dislike') return 'Không thích';
    return 'Chưa bình chọn';
  }

  Color _voteColor(String vote, {required bool mine}) {
    if (vote == 'Like') {
      return mine ? Colors.green.shade700 : Colors.green.shade100;
    }
    if (vote == 'Dislike') {
      return mine ? Colors.red.shade700 : Colors.red.shade100;
    }
    return Colors.grey.shade200;
  }

  bool _bothLiked(SharedSpaceShortlistItem item) =>
      item.myVote == 'Like' && item.partnerVote == 'Like';

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await action();
      await _loadSpace();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thực hiện: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notFound || _space == null) {
      return _EmptyState(
        onChat: () => context.go('/chat'),
        onDiscovery: () => context.go('/discovery'),
      );
    }

    final space = _space!;
    final proposed = _proposedRoom;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () {
                  if (space.partnerId.isNotEmpty) {
                    context.go(
                      Uri(
                        path: '/chat',
                        queryParameters: {
                          'with': space.partnerId,
                          'name': space.partnerName,
                          'role': 'tenant',
                        },
                      ).toString(),
                    );
                  } else {
                    context.go('/chat');
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Quay lại'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              ),
              Text(
                'KHÔNG GIAN TÌM TRỌ CHUNG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SacoColors.sacoOrange,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${space.myName} & ${space.partnerName}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Cùng lọc phòng, bình chọn và chốt căn phù hợp nhất cho hành trình ở ghép.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              if (_isActive) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/rooms'),
                  style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                  child: const Text('Tìm phòng trọ'),
                ),
              ],
              if (_isPendingFinalize && _isProposer) ...[
                const SizedBox(height: 20),
                _BannerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đã gửi đề xuất chốt, vui lòng đợi bạn cùng phòng phê duyệt…',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (proposed != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${proposed.roomTitle} — ${_formatPrice(proposed.price)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _actionLoading
                            ? null
                            : () => _runAction(() async {
                                  final msg = await ref
                                      .read(sharedSpaceRepositoryProvider)
                                      .rejectFinalize(space.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text(msg)));
                                  }
                                }),
                        child: const Text('Hủy yêu cầu đề xuất'),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isApprover) ...[
                const SizedBox(height: 20),
                _BannerCard(
                  highlight: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${space.partnerName} đề xuất chốt phòng',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (proposed != null) ...[
                        const SizedBox(height: 6),
                        Text(proposed.roomTitle, style: TextStyle(color: Colors.grey.shade600)),
                        Text(
                          _formatPrice(proposed.price),
                          style: const TextStyle(
                            color: SacoColors.sacoOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (proposed.address.isNotEmpty)
                          Text(
                            proposed.address,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _actionLoading
                                  ? null
                                  : () => _runAction(() async {
                                        final msg = await ref
                                            .read(sharedSpaceRepositoryProvider)
                                            .acceptFinalize(space.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(msg)),
                                          );
                                        }
                                      }),
                              style: FilledButton.styleFrom(
                                backgroundColor: SacoColors.sacoOrange,
                              ),
                              child: const Text('Đồng ý chốt'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _actionLoading
                                  ? null
                                  : () => _runAction(() async {
                                        final msg = await ref
                                            .read(sharedSpaceRepositoryProvider)
                                            .rejectFinalize(space.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(content: Text(msg)));
                                        }
                                      }),
                              child: const Text('Từ chối'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_isFinalized) ...[
                const SizedBox(height: 20),
                _BannerCard(
                  done: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đã chốt phòng thành công!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (proposed != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          proposed.roomTitle,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (space.finalizedRoomId != null)
                        FilledButton(
                          onPressed: () => context.go('/rooms/${space.finalizedRoomId}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: SacoColors.sacoOrange,
                          ),
                          child: const Text('Xem phòng đã chốt'),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => context.go(
                          Uri(
                            path: '/chat',
                            queryParameters: {
                              'with': space.partnerId,
                              'name': space.partnerName,
                              'role': 'tenant',
                            },
                          ).toString(),
                        ),
                        child: const Text('Nhắn tin bạn cùng phòng'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Danh sách phòng cân nhắc',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${space.shortlist.length} phòng',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (space.shortlist.isEmpty)
                _BannerCard(
                  child: Column(
                    children: [
                      Text(
                        'Chưa có phòng nào trong danh sách chung.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/rooms'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SacoColors.sacoOrange,
                        ),
                        child: const Text('Tìm phòng trọ'),
                      ),
                    ],
                  ),
                )
              else
                ...space.shortlist.map((item) => _RoomCard(
                      item: item,
                      partnerName: space.partnerName,
                      locked: !_isActive,
                      actionLoading: _actionLoading,
                      formatPrice: _formatPrice,
                      voteLabel: _voteLabel,
                      voteColor: _voteColor,
                      bothLiked: _bothLiked(item),
                      onView: () => context.go('/rooms/${item.roomId}'),
                      onVote: (vote) => _runAction(() async {
                        final msg = await ref
                            .read(sharedSpaceRepositoryProvider)
                            .voteRoom(item.id, vote);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      }),
                      onPropose: () => _runAction(() async {
                        final msg = await ref
                            .read(sharedSpaceRepositoryProvider)
                            .proposeFinalize(space.id, item.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      }),
                    )),
            ],
          ),
        ),
        if (_showCelebration)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      const Text(
                        'Chúc mừng!',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hai bạn đã thống nhất chốt phòng. Hãy liên hệ chủ trọ và hoàn tất thủ tục thuê trọ nhé.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() => _showCelebration = false),
                        style: FilledButton.styleFrom(
                          backgroundColor: SacoColors.sacoOrange,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Tuyệt vời!'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onChat, required this.onDiscovery});

  final VoidCallback onChat;
  final VoidCallback onDiscovery;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Column(
          children: [
            const Text('🏠', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Chưa có không gian chung',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn chưa khởi tạo không gian tìm trọ chung với ai.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SacoColors.pageBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: const Text(
                'Trong không gian chung, hai bạn sẽ:\n'
                '1. Cùng thêm các phòng trọ muốn cân nhắc vào danh sách chung\n'
                '2. Bình chọn Thích hoặc Không thích từng phòng\n'
                '3. Khi cả hai cùng thích — một người đề xuất chốt, người kia xác nhận\n\n'
                'Mở cuộc trò chuyện trên Tin nhắn với người bạn đã match, rồi nhấn Tạo không gian chung.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onChat,
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Đi tới Tin nhắn'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onDiscovery,
              child: const Text('Tìm bạn'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.child,
    this.highlight = false,
    this.done = false,
  });

  final Widget child;
  final bool highlight;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: done
            ? Colors.green.shade50
            : highlight
                ? Colors.orange.shade50
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done
              ? Colors.green.shade200
              : highlight
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.item,
    required this.partnerName,
    required this.locked,
    required this.actionLoading,
    required this.formatPrice,
    required this.voteLabel,
    required this.voteColor,
    required this.bothLiked,
    required this.onView,
    required this.onVote,
    required this.onPropose,
  });

  final SharedSpaceShortlistItem item;
  final String partnerName;
  final bool locked;
  final bool actionLoading;
  final String Function(int) formatPrice;
  final String Function(String) voteLabel;
  final Color Function(String, {required bool mine}) voteColor;
  final bool bothLiked;
  final VoidCallback onView;
  final ValueChanged<String> onVote;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.roomTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.roomCategory != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(item.roomCategory!, style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                    if (item.address.isNotEmpty)
                      Text(
                        item.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    Text(
                      '${formatPrice(item.price)}/tháng',
                      style: const TextStyle(
                        color: SacoColors.sacoOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.isAddedByMe)
                      Text(
                        'Bạn đã thêm phòng này',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onView,
                child: const Text('Xem', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bạn', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: voteColor(item.myVote, mine: true),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        voteLabel(item.myVote),
                        style: TextStyle(
                          fontSize: 12,
                          color: item.myVote == 'None' ? Colors.grey.shade700 : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partnerName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: voteColor(item.partnerVote, mine: false),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        voteLabel(item.partnerVote),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!locked) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: actionLoading ? null : () => onVote('Like'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: item.myVote == 'Like' ? Colors.green.shade700 : null,
                    side: BorderSide(
                      color: item.myVote == 'Like' ? Colors.green : Colors.grey.shade300,
                    ),
                  ),
                  child: const Text('👍 Thích'),
                ),
                OutlinedButton(
                  onPressed: actionLoading ? null : () => onVote('Dislike'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: item.myVote == 'Dislike' ? Colors.red.shade700 : null,
                    side: BorderSide(
                      color: item.myVote == 'Dislike' ? Colors.red : Colors.grey.shade300,
                    ),
                  ),
                  child: const Text('👎 Không thích'),
                ),
                if (bothLiked)
                  FilledButton(
                    onPressed: actionLoading ? null : onPropose,
                    style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
                    child: const Text('Đề xuất chốt phòng'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
