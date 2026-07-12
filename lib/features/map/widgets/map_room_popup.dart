import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../models/room_post.dart';

String mapLocationLine(RoomPostSummary room) {
  final parts = [room.district, room.city]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(', ');
  if (parts.isNotEmpty) return parts;
  return room.address ?? '—';
}

String mapPriceVnd(int? price) {
  if (price == null || price <= 0) return 'Liên hệ';
  return '${NumberFormat('#,###', 'vi_VN').format(price)} đ/tháng';
}

class MapRoomPopup extends StatelessWidget {
  const MapRoomPopup({
    super.key,
    required this.room,
    required this.onClose,
  });

  final RoomPostSummary room;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: room.imageUrl != null
                      ? Image.network(
                          room.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onClose,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: SacoColors.sacoBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mapLocationLine(room),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mapPriceVnd(room.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: SacoColors.sacoOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => context.push('/rooms/${room.id}'),
                    child: const Text(
                      'Xem chi tiết →',
                      style: TextStyle(
                        color: SacoColors.sacoOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(
        'Chưa có ảnh',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    );
  }
}
