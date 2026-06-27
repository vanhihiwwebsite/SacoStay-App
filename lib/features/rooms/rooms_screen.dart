import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/room_filters.dart';
import '../../core/utils/vip_tier.dart';
import '../../models/room_post.dart';
import '../../shared/widgets/saco_footer.dart';
import 'room_providers.dart';
import 'widgets/room_card.dart';
import 'widgets/room_filters_panel.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _filters = RoomListFilters();
  bool _showFilterPanel = false;

  @override
  Widget build(BuildContext context) {
    final asyncRooms = ref.watch(roomPostsProvider);

    return asyncRooms.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không tải được danh sách phòng: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(roomPostsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (allRooms) {
        final filtered = sortRoomsByVipTier(
          applyRoomFilters(allRooms, _filters),
        );
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(roomPostsProvider);
            await ref.read(roomPostsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                          const Text(
                            'Phòng trọ nổi bật',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Danh sách phòng trọ đã được xác thực',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Xem bản đồ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _filterBar(),
                if (_showFilterPanel)
                  RoomFiltersPanel(
                    filters: _filters,
                    onChanged: (f) => setState(() {
                      _filters.city = f.city;
                      _filters.district = f.district;
                      _filters.priceMin = f.priceMin;
                      _filters.priceMax = f.priceMax;
                      _filters.maxOccupants = f.maxOccupants;
                      _filters.amenities
                        ..clear()
                        ..addAll(f.amenities);
                    }),
                    onClose: () => setState(() => _showFilterPanel = false),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${filtered.length} phòng phù hợp',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Không có phòng phù hợp bộ lọc'),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: crossAxisCount == 1 ? 0.92 : 0.78,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => RoomCard(
                          room: filtered[i],
                          compact: true,
                        ),
                      );
                    },
                  ),
                const SacoFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterBar() {
    final count = activeFilterCount(_filters);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 16),
              const SizedBox(width: 6),
              const Text('Bộ lọc'),
              if (count > 0) ...[
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: _showFilterPanel
                      ? Colors.white
                      : SacoColors.sacoOrange,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: _showFilterPanel
                          ? SacoColors.sacoOrange
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected: _showFilterPanel,
          selectedColor: SacoColors.sacoOrange,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: _showFilterPanel ? Colors.white : Colors.grey.shade800,
          ),
          onSelected: (_) => setState(() => _showFilterPanel = !_showFilterPanel),
        ),
        if (_filters.city != 'all')
          _activeChip(_filters.city, () => setState(() => _filters.city = 'all')),
        if (_filters.district != 'all')
          _activeChip(
            _filters.district,
            () => setState(() => _filters.district = 'all'),
          ),
        if (_filters.priceMin > 0 || _filters.priceMax < 50000000)
          _activeChip(
            '${(_filters.priceMin / 1000000).toStringAsFixed(1)}tr - ${(_filters.priceMax / 1000000).toStringAsFixed(1)}tr',
            () => setState(() {
              _filters.priceMin = 0;
              _filters.priceMax = 50000000;
            }),
          ),
        for (final a in _filters.amenities)
          _activeChip(a, () => setState(() => _filters.amenities.remove(a))),
      ],
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: SacoColors.sacoOrange.withValues(alpha: 0.1),
      side: BorderSide(color: SacoColors.sacoOrange.withValues(alpha: 0.3)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
    );
  }
}
