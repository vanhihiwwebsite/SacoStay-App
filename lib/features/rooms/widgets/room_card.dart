import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/utils/room_filters.dart';
import '../../../core/utils/vip_tier.dart';
import '../../../models/room_post.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.compact = false,
    this.onTap,
  });

  final RoomPostSummary room;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tier = room.vipTier;
    final address = room.address ??
        [room.district, room.city].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: SacoColors.sacoOrange.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => context.push('/rooms/${room.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (room.imageUrl != null && room.imageUrl!.isNotEmpty)
                    Image.network(
                      room.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderImage(),
                    )
                  else
                    _placeholderImage(),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: vipTierPriceBadgeColor(tier),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        formatRoomListPrice(room.price),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: vipTierTitleStyle(tier).copyWith(fontSize: compact ? 16 : 17),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: SacoColors.sacoOrange.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.home_outlined, size: 48, color: Colors.grey),
      ),
    );
  }
}
