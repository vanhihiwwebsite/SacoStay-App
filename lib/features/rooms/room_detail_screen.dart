import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/user_display.dart';
import '../../core/utils/vip_tier.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/room_post.dart';
import '../../models/shared_space.dart';
import '../../repositories/room_post_repository.dart';
import '../../repositories/shared_space_repository.dart';
import 'room_providers.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  int _galleryIndex = 0;
  bool _viewRecorded = false;
  List<SharedSpaceSummary> _sharedSpaces = [];
  bool _addingToShortlist = false;

  Future<void> _loadSharedSpaceState(String roomId) async {
    if (!ref.read(authControllerProvider).isLoggedIn) return;
    if (isLandlordUser(ref.read(authControllerProvider).user?.raw)) return;
    try {
      final spaces = await ref.read(sharedSpaceRepositoryProvider).listSpaces();
      if (!mounted) return;
      setState(() => _sharedSpaces = spaces);
    } catch (_) {
      if (mounted) setState(() => _sharedSpaces = []);
    }
  }

  List<SharedSpaceSummary> get _activeSharedSpaces =>
      _sharedSpaces.where((s) => s.status == 'Active').toList();

  List<SharedSpaceSummary> _addableSpaces(String roomId) =>
      _activeSharedSpaces.where((s) => !s.shortlistRoomIds.contains(roomId)).toList();

  bool _sharedShortlistAdded(String roomId) {
    if (_activeSharedSpaces.isEmpty) return false;
    return _activeSharedSpaces.every((s) => s.shortlistRoomIds.contains(roomId));
  }

  Future<void> _addToSharedShortlist(RoomPostDetail room) async {
    if (_addingToShortlist) return;
    final candidates = _addableSpaces(room.id);
    if (candidates.isEmpty) return;

    String spaceId;
    if (candidates.length == 1) {
      spaceId = candidates.first.id;
    } else {
      final picked = await showModalBottomSheet<SharedSpaceSummary>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chọn không gian chung',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...candidates.map(
                (s) => ListTile(
                  title: Text(s.partnerName),
                  subtitle: Text('${s.shortlistRoomIds.length} phòng trong danh sách'),
                  onTap: () => Navigator.pop(ctx, s),
                ),
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      spaceId = picked.id;
    }

    setState(() => _addingToShortlist = true);
    try {
      final partner = _sharedSpaces.firstWhere((s) => s.id == spaceId).partnerName;
      final msg = await ref.read(sharedSpaceRepositoryProvider).addToShortlist(spaceId, room.id);
      await _loadSharedSpaceState(room.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$msg\n$partner')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thêm phòng: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToShortlist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRoom = ref.watch(roomDetailProvider(widget.roomId));
    final auth = ref.watch(authControllerProvider);
    final isLandlord = isLandlordUser(auth.user?.raw);

    return asyncRoom.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (room) {
        if (room == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tìm thấy tin đăng này.'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/rooms'),
                  child: const Text('Quay lại danh sách'),
                ),
              ],
            ),
          );
        }

        if (auth.isLoggedIn && !_viewRecorded) {
          _viewRecorded = true;
          ref.read(roomPostRepositoryProvider).recordView(room.id);
          _loadSharedSpaceState(room.id);
        }

        final images = room.galleryImages;
        if (_galleryIndex >= images.length) {
          _galleryIndex = 0;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      final from = GoRouterState.of(context).uri.queryParameters['from'];
                      if (from == 'my-listings') {
                        context.go('/my-listings');
                      } else {
                        context.go('/rooms');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      isLandlord ? 'Chi tiết tin đăng' : 'Chi tiết phòng',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              _GallerySection(
                images: images,
                title: room.title,
                index: _galleryIndex,
                onIndexChanged: (i) => setState(() => _galleryIndex = i),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final main = _MainContent(room: room);
                  final sidebar = _PriceSidebar(
                    room: room,
                    isLandlord: isLandlord,
                    canMessage: !isLandlord &&
                        room.landlordUserId != null &&
                        room.landlordUserId!.isNotEmpty,
                    canAddToSharedShortlist: !isLandlord && _addableSpaces(room.id).isNotEmpty,
                    sharedShortlistAdded: _sharedShortlistAdded(room.id),
                    addingToShortlist: _addingToShortlist,
                    onAddToSharedShortlist: () => _addToSharedShortlist(room),
                    onChat: () {
                      final id = room.landlordUserId!;
                      context.go(
                        Uri(
                          path: '/chat',
                          queryParameters: {'with': id, 'role': 'landlord'},
                        ).toString(),
                      );
                    },
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: main),
                        const SizedBox(width: 24),
                        Expanded(flex: 1, child: sidebar),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      main,
                      const SizedBox(height: 20),
                      sidebar,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.images,
    required this.title,
    required this.index,
    required this.onIndexChanged,
  });

  final List<String> images;
  final String title;
  final int index;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text('Chưa có ảnh', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(images[index], fit: BoxFit.cover),
                if (images.length > 1)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      onPressed: () => onIndexChanged(
                        index <= 0 ? images.length - 1 : index - 1,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ),
                if (images.length > 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      onPressed: () =>
                          onIndexChanged((index + 1) % images.length),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ),
                if (images.length > 1)
                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1} / ${images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == index;
                return GestureDetector(
                  onTap: () => onIndexChanged(i),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? SacoColors.sacoOrange
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(images[i], fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({required this.room});

  final RoomPostDetail room;

  @override
  Widget build(BuildContext context) {
    final location = room.address ??
        [room.district, room.city].whereType<String>().join(', ');
    final people = room.maxPeople != null
        ? '${room.currentPeople ?? room.occupants.length}/${room.maxPeople}'
        : '—';
    final status = _statusLabel(room.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(room.title, style: vipTierTitleStyle(room.vipTier)),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(location, style: TextStyle(color: Colors.grey.shade600)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            _statCard('Diện tích', room.area != null ? '${room.area!.round()}m²' : '—'),
            const SizedBox(width: 8),
            _statCard('Số người', people),
            const SizedBox(width: 8),
            _statCard('Trạng thái', status),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Mô tả', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          room.description?.trim().isNotEmpty == true
              ? room.description!
              : 'Chưa có mô tả chi tiết cho tin này.',
          style: TextStyle(
            color: room.description != null ? Colors.grey.shade700 : Colors.grey,
            fontStyle:
                room.description?.trim().isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        if (room.amenities.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Tiện nghi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: room.amenities
                .map(
                  (a) => Chip(
                    label: Text(a),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                )
                .toList(),
          ),
        ],
        if (room.occupants.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Bạn cùng phòng hiện tại',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...room.occupants.map((u) {
            final avatar = u.avatar ??
                avatarFallbackUrl(u.name);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(avatar),
                ),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  [
                    if (u.age != null) '${u.age} tuổi',
                    if (u.occupation != null) u.occupation!,
                  ].join(' • '),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.isEmpty || s == 'active' || s == 'published' || s == 'approved') {
      return 'Có sẵn';
    }
    return status ?? 'Có sẵn';
  }
}

class _PriceSidebar extends StatelessWidget {
  const _PriceSidebar({
    required this.room,
    required this.isLandlord,
    required this.canMessage,
    required this.canAddToSharedShortlist,
    required this.sharedShortlistAdded,
    required this.addingToShortlist,
    required this.onAddToSharedShortlist,
    required this.onChat,
  });

  final RoomPostDetail room;
  final bool isLandlord;
  final bool canMessage;
  final bool canAddToSharedShortlist;
  final bool sharedShortlistAdded;
  final bool addingToShortlist;
  final VoidCallback onAddToSharedShortlist;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final priceText = room.price != null && room.price! > 0
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(room.price)
        : 'Liên hệ';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Giá thuê', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            priceText,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const Text('/tháng', style: TextStyle(color: Colors.grey)),
          if (!isLandlord) ...[
            const SizedBox(height: 20),
            if (canAddToSharedShortlist)
              OutlinedButton(
                onPressed: addingToShortlist ? null : onAddToSharedShortlist,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SacoColors.sacoOrange,
                  side: const BorderSide(color: SacoColors.sacoOrange, width: 2),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(addingToShortlist ? 'Đang thêm…' : 'Thêm vào nhóm'),
              ),
            if (sharedShortlistAdded) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Đã thêm vào danh sách chung'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Liên hệ xem phòng'),
            ),
            const SizedBox(height: 8),
            if (canMessage)
              OutlinedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Nhắn tin cho chủ trọ'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              )
            else
              Text(
                'Chưa có thông tin chủ trọ để nhắn tin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Địa điểm gần đó',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (room.nearbyLandmarks.isEmpty)
            Text(
              'Chưa có điểm tham chiếu gần vị trí ghim.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          else
            Column(
              children: room.nearbyLandmarks
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.place_outlined,
                              size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(item, style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
