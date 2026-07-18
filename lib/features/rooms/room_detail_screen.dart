import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/user_display.dart';
import '../../core/utils/vip_tier.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/room_post.dart';
import '../../models/shared_space.dart';
import '../../repositories/room_post_repository.dart';
import '../../repositories/shared_space_repository.dart';
import '../../shared/widgets/report_modal.dart';
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
  bool _resolvingPhone = false;
  String? _resolvedLandlordPhone;
  String? _phoneLookupUserId;

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

  Future<String?> _resolveLandlordPhone(RoomPostDetail room) async {
    final inline = room.landlordPhone?.replaceAll(RegExp(r'\s'), '');
    if (inline != null && inline.isNotEmpty) return inline;

    final landlordId = room.landlordUserId;
    if (landlordId == null || landlordId.isEmpty) return null;

    if (_phoneLookupUserId == landlordId &&
        _resolvedLandlordPhone != null &&
        _resolvedLandlordPhone!.isNotEmpty) {
      return _resolvedLandlordPhone;
    }

    final phone =
        await ref.read(authRepositoryProvider).fetchLandlordContactPhone(landlordId);
    if (!mounted) return phone;
    if (phone != null && phone.isNotEmpty) {
      setState(() {
        _phoneLookupUserId = landlordId;
        _resolvedLandlordPhone = phone;
      });
    }
    return phone;
  }

  String? _normalizeDialNumber(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('0')) return digits;
    if (digits.length == 9 || digits.length == 10) return '0$digits';
    return digits.isNotEmpty ? digits : null;
  }

  Future<void> _callLandlord(RoomPostDetail room) async {
    if (_resolvingPhone) return;
    setState(() => _resolvingPhone = true);
    try {
      final phone = await _resolveLandlordPhone(room);
      final normalized = phone != null ? _normalizeDialNumber(phone) : null;
      if (normalized == null || normalized.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa có số điện thoại chủ trọ.')),
          );
        }
        return;
      }
      final uri = Uri(scheme: 'tel', path: normalized);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở ứng dụng gọi điện.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingPhone = false);
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

        final canMessage = !isLandlord &&
            room.landlordUserId != null &&
            room.landlordUserId!.isNotEmpty;

        return ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RoomDetailHeader(
                isLandlord: isLandlord,
                onBack: () {
                  final from = GoRouterState.of(context).uri.queryParameters['from'];
                  if (from == 'my-listings') {
                    context.go('/my-listings');
                  } else {
                    context.go('/rooms');
                  }
                },
                onReport: !isLandlord
                    ? () => showReportModal(
                          context,
                          type: ReportTargetType.room,
                          targetName: room.title,
                          reportedRoomId: room.id,
                        )
                    : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GallerySection(
                        images: images,
                        title: room.title,
                        index: _galleryIndex,
                        onIndexChanged: (i) => setState(() => _galleryIndex = i),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900;
                          final main = _MainContent(room: room);
                          final sidebar = _PriceSidebar(
                            room: room,
                            isLandlord: isLandlord,
                            canMessage: canMessage,
                            canAddToSharedShortlist:
                                !isLandlord && _addableSpaces(room.id).isNotEmpty,
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
                            onContact: () => _callLandlord(room),
                            hidePrimaryActions: !wide && !isLandlord,
                            hidePriceSection: !wide && !isLandlord,
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
                ),
              ),
              if (!isLandlord)
                _TenantActionBar(
                  canMessage: canMessage,
                  canAddToGroup: _activeSharedSpaces.isNotEmpty,
                  sharedShortlistAdded: _sharedShortlistAdded(room.id),
                  addingToShortlist: _addingToShortlist,
                  contacting: _resolvingPhone,
                  onAddToGroup: () {
                    if (_sharedShortlistAdded(room.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phòng đã có trong danh sách chung.')),
                      );
                      return;
                    }
                    if (_activeSharedSpaces.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hãy tạo không gian chung trước.')),
                      );
                      return;
                    }
                    _addToSharedShortlist(room);
                  },
                  onChat: () {
                    final id = room.landlordUserId!;
                    context.go(
                      Uri(
                        path: '/chat',
                        queryParameters: {'with': id, 'role': 'landlord'},
                      ).toString(),
                    );
                  },
                  onContact: () => _callLandlord(room),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomDetailHeader extends StatelessWidget {
  const _RoomDetailHeader({
    required this.isLandlord,
    required this.onBack,
    this.onReport,
  });

  final bool isLandlord;
  final VoidCallback onBack;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: Colors.black87,
              ),
              Expanded(
                child: Text(
                  isLandlord ? 'Chi tiết tin đăng' : 'Chi tiết phòng',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (onReport != null)
                IconButton(
                  onPressed: onReport,
                  icon: Icon(Icons.flag_outlined, color: Colors.red.shade400),
                  tooltip: 'Báo cáo',
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomNetworkImage extends StatelessWidget {
  const _RoomNetworkImage({required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey.shade400,
          size: 28,
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
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
                _RoomNetworkImage(url: images[index], fit: BoxFit.cover),
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
                            ? const Color(0xFFE53935)
                            : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _RoomNetworkImage(url: images[i], fit: BoxFit.cover),
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
    final priceText = room.price != null && room.price! > 0
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(room.price)
        : 'Liên hệ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('Phòng trọ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(width: 12),
            Icon(Icons.wc, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('Nam / Nữ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          room.title.toUpperCase(),
          style: vipTierTitleStyle(room.vipTier).copyWith(
            fontSize: 18,
            height: 1.3,
            color: SacoColors.sacoBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$priceText/tháng',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFFC62828),
          ),
        ),
        const SizedBox(height: 16),
        if (location.isNotEmpty)
          _detailRow(Icons.location_on_outlined, 'Địa chỉ', location),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    required this.onContact,
    this.hidePrimaryActions = false,
    this.hidePriceSection = false,
  });

  final RoomPostDetail room;
  final bool isLandlord;
  final bool canMessage;
  final bool canAddToSharedShortlist;
  final bool sharedShortlistAdded;
  final bool addingToShortlist;
  final VoidCallback onAddToSharedShortlist;
  final VoidCallback onChat;
  final VoidCallback onContact;
  final bool hidePrimaryActions;
  final bool hidePriceSection;

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
          if (!hidePriceSection) ...[
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
          ],
          if (!isLandlord && !hidePrimaryActions) ...[
            if (!hidePriceSection) const SizedBox(height: 20),
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
              onPressed: onContact,
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
          ] else if (!isLandlord && hidePrimaryActions) ...[
            const SizedBox(height: 8),
            Text(
              'Dùng thanh hành động phía dưới để thêm vào nhóm, nhắn tin hoặc liên hệ xem phòng.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
          if (!hidePriceSection || !isLandlord) const SizedBox(height: 20),
          if (hidePriceSection && isLandlord) const SizedBox(height: 8),
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

class _TenantActionBar extends StatelessWidget {
  const _TenantActionBar({
    required this.canMessage,
    required this.canAddToGroup,
    required this.sharedShortlistAdded,
    required this.addingToShortlist,
    required this.contacting,
    required this.onAddToGroup,
    required this.onChat,
    required this.onContact,
  });

  final bool canMessage;
  final bool canAddToGroup;
  final bool sharedShortlistAdded;
  final bool addingToShortlist;
  final bool contacting;
  final VoidCallback onAddToGroup;
  final VoidCallback onChat;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final addEnabled = canAddToGroup && !sharedShortlistAdded && !addingToShortlist;

    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: OutlinedButton(
                  onPressed: addEnabled ? onAddToGroup : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: SacoColors.sacoOrange,
                    side: BorderSide(color: Colors.orange.shade200),
                    backgroundColor: Colors.orange.shade50,
                  ),
                  child: addingToShortlist
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          sharedShortlistAdded ? Icons.check : Icons.add,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: OutlinedButton(
                  onPressed: canMessage ? onChat : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: SacoColors.sacoOrange,
                    side: BorderSide(color: Colors.orange.shade200),
                    backgroundColor: Colors.orange.shade50,
                  ),
                  child: const Icon(Icons.chat_bubble_outline, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: contacting ? null : onContact,
                  icon: contacting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.phone_outlined, size: 18),
                  label: Text(
                    contacting ? 'Đang tải…' : 'Liên hệ xem phòng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: SacoColors.sacoOrange,
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
