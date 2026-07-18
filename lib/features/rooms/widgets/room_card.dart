import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    final district = room.district ?? room.city ?? '';
    final areaLabel = room.area != null ? '${room.area!.round()}m²' : null;
    final peopleLabel = room.maxPeople != null ? '${room.maxPeople}' : null;

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => context.push('/rooms/${room.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                      ? Image.network(
                          room.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImage(),
                        )
                      : _placeholderImage(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: vipTierTitleStyle(tier, compact: compact),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      room.price != null && room.price! > 0
                          ? 'Từ ${formatRoomListPrice(room.price)}'
                          : 'Liên hệ',
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (district.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.apartment_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              district,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (areaLabel != null) ...[
                          Icon(Icons.square_foot_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(areaLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          const SizedBox(width: 12),
                        ],
                        if (peopleLabel != null) ...[
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(peopleLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.home_outlined, size: 36, color: Colors.grey),
      ),
    );
  }
}
