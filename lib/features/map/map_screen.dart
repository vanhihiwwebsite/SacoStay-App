import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme.dart';
import '../../core/utils/room_filters.dart';
import '../../core/utils/vip_tier.dart';
import '../../models/room_post.dart';
import '../rooms/room_providers.dart';
import '../rooms/widgets/room_filters_panel.dart';
import 'widgets/house_map_marker.dart';
import 'widgets/map_room_popup.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  RoomListFilters _filters = RoomListFilters();
  RoomPostSummary? _selectedRoom;
  bool _showFilters = false;
  bool _showMobileList = false;
  String _mapCity = 'Hà Nội';

  static const _hanoi = LatLng(21.0285, 105.8542);
  static const _hcm = LatLng(10.7769, 106.7009);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _centerOnCity(String city) {
    _mapCity = city;
    final target = city == 'TP.HCM' ? _hcm : _hanoi;
    _mapController.move(target, 12);
  }

  void _selectRoom(RoomPostSummary room, {bool collapseList = false}) {
    setState(() {
      _selectedRoom = room;
      if (collapseList) _showMobileList = false;
    });
    if (room.hasCoordinates) {
      _mapController.move(
        LatLng(room.latitude!, room.longitude!),
        16,
      );
    }
  }

  void _clearSelection() {
    if (_selectedRoom == null) return;
    setState(() => _selectedRoom = null);
  }

  @override
  Widget build(BuildContext context) {
    final asyncRooms = ref.watch(roomPostsProvider);

    return asyncRooms.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải bản đồ: $e')),
      data: (allRooms) {
        _filters.searchQuery = _searchController.text;
        final filtered = sortRoomsByVipTier(
          applyRoomFilters(allRooms, _filters),
        );
        final onMap = filtered.where((r) => r.hasCoordinates).toList();
        final minPrice = filtered
            .map((r) => r.price)
            .whereType<int>()
            .where((p) => p > 0)
            .fold<int?>(null, (min, p) => min == null ? p : (p < min ? p : min));

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final mapArea = _MapArea(
              controller: _mapController,
              rooms: onMap,
              selectedRoom: _selectedRoom,
              onSelect: _selectRoom,
              onClearSelection: _clearSelection,
              initialCenter: _mapCity == 'TP.HCM' ? _hcm : _hanoi,
            );

            Widget buildMapStack({required bool showListButton, List<Widget> extra = const []}) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: mapArea),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _MapSearchBar(
                      searchController: _searchController,
                      filters: _filters,
                      onSearchChanged: () => setState(() {}),
                      onToggleFilters: () => setState(() => _showFilters = !_showFilters),
                      onCityQuick: (city) {
                        setState(() {
                          _filters.city = city;
                          _filters.district = 'all';
                        });
                        _centerOnCity(city);
                      },
                    ),
                  ),
                  if (!_showFilters)
                    Positioned(
                      bottom: 16,
                      left: 12,
                      right: 12,
                      child: _MapStatsBar(
                        filteredCount: filtered.length,
                        minPriceM: minPrice != null
                            ? (minPrice / 1000000).toStringAsFixed(1)
                            : null,
                        showListButton: showListButton,
                        onOpenList: () => setState(() => _showMobileList = true),
                      ),
                    ),
                  if (_showFilters)
                    Positioned.fill(
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 420,
                                maxHeight: MediaQuery.of(context).size.height * 0.82,
                              ),
                              child: RoomFiltersPanel(
                                scrollable: true,
                                filters: _filters,
                                resultCount: filtered.length,
                                onChanged: (f) => setState(() {
                                  _filters = f.copy();
                                  if (f.city == 'Hà Nội' || f.city == 'TP.HCM') {
                                    _centerOnCity(f.city);
                                  }
                                }),
                                onClose: () => setState(() => _showFilters = false),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ...extra,
                ],
              );
            }

            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: buildMapStack(
                      showListButton: false,
                      extra: [
                        if (_selectedRoom != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 88,
                            child: Align(
                              child: MapRoomPopup(
                                room: _selectedRoom!,
                                onClose: _clearSelection,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 302,
                    child: _RoomSidebar(
                      rooms: filtered,
                      selectedRoom: _selectedRoom,
                      onSelect: _selectRoom,
                      onDetail: (id) => context.push('/rooms/$id'),
                    ),
                  ),
                ],
              );
            }

            return buildMapStack(
              showListButton: true,
              extra: [
                if (_selectedRoom != null && !_showMobileList)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 88,
                    child: Align(
                      child: MapRoomPopup(
                        room: _selectedRoom!,
                        onClose: _clearSelection,
                      ),
                    ),
                  ),
                if (_showMobileList)
                  Positioned.fill(
                    child: _MobileListSheet(
                      rooms: filtered,
                      selectedRoom: _selectedRoom,
                      onClose: () => setState(() => _showMobileList = false),
                      onSelect: (room) => _selectRoom(room, collapseList: true),
                      onDetail: (id) {
                        setState(() => _showMobileList = false);
                        context.push('/rooms/$id');
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({
    required this.controller,
    required this.rooms,
    required this.selectedRoom,
    required this.onSelect,
    required this.onClearSelection,
    required this.initialCenter,
  });

  final MapController controller;
  final List<RoomPostSummary> rooms;
  final RoomPostSummary? selectedRoom;
  final ValueChanged<RoomPostSummary> onSelect;
  final VoidCallback onClearSelection;
  final LatLng initialCenter;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 12,
        minZoom: 5,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: (_, __) => onClearSelection(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.sacostay',
        ),
        MarkerLayer(
          markers: rooms.map((room) {
            final selected = selectedRoom?.id == room.id;
            return Marker(
              point: LatLng(room.latitude!, room.longitude!),
              width: 36,
              height: 42,
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () => onSelect(room),
                child: HouseMapMarker(
                  tier: room.vipTier,
                  selected: selected,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.searchController,
    required this.filters,
    required this.onSearchChanged,
    required this.onToggleFilters,
    required this.onCityQuick,
  });

  final TextEditingController searchController;
  final RoomListFilters filters;
  final VoidCallback onSearchChanged;
  final VoidCallback onToggleFilters;
  final ValueChanged<String> onCityQuick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Tìm phòng, quận, tiện ích...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: onToggleFilters,
                icon: const Icon(Icons.tune),
              ),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _cityButton('Hà Nội', filters.city == 'Hà Nội', () => onCityQuick('Hà Nội')),
            const SizedBox(width: 8),
            _cityButton('TP.HCM', filters.city == 'TP.HCM', () => onCityQuick('TP.HCM')),
          ],
        ),
      ],
    );
  }

  Widget _cityButton(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? SacoColors.sacoOrange : Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStatsBar extends StatelessWidget {
  const _MapStatsBar({
    required this.filteredCount,
    required this.minPriceM,
    this.showListButton = false,
    this.onOpenList,
  });

  final int filteredCount;
  final String? minPriceM;
  final bool showListButton;
  final VoidCallback? onOpenList;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Tìm thấy', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(
                    '$filteredCount phòng',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: SacoColors.sacoOrange,
                      fontSize: 12,
                    ),
                  ),
                  if (minPriceM != null) ...[
                    Text('|', style: TextStyle(color: Colors.grey.shade300)),
                    Text('Từ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text('${minPriceM}tr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (showListButton && onOpenList != null) ...[
              const SizedBox(width: 8),
              Material(
                color: SacoColors.sacoOrange,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenList,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.list_alt, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Danh sách ($filteredCount)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomSidebar extends StatelessWidget {
  const _RoomSidebar({
    required this.rooms,
    required this.selectedRoom,
    required this.onSelect,
    required this.onDetail,
  });

  final List<RoomPostSummary> rooms;
  final RoomPostSummary? selectedRoom;
  final ValueChanged<RoomPostSummary> onSelect;
  final ValueChanged<String> onDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danh sách phòng trọ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${rooms.length} phòng phù hợp',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (_, i) {
                final room = rooms[i];
                final selected = selectedRoom?.id == room.id;
                return Material(
                  color: selected ? SacoColors.sacoOrange : Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(room),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: room.imageUrl != null
                                ? Image.network(
                                    room.imageUrl!,
                                    width: 64,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                                  )
                                : _thumbPlaceholder(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: vipTierTitleStyle(room.vipTier).copyWith(
                                    fontSize: 13,
                                    color: selected ? Colors.white : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mapListPrice(room.price),
                                  style: TextStyle(
                                    color: selected ? Colors.white : SacoColors.sacoOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (selectedRoom != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () => onDetail(selectedRoom!.id),
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                ),
                child: const Text('Xem chi tiết'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 64,
      height: 56,
      color: Colors.grey.shade200,
      child: const Icon(Icons.home_outlined, color: Colors.grey),
    );
  }
}

class _MobileListSheet extends StatelessWidget {
  const _MobileListSheet({
    required this.rooms,
    required this.selectedRoom,
    required this.onClose,
    required this.onSelect,
    required this.onDetail,
  });

  final List<RoomPostSummary> rooms;
  final RoomPostSummary? selectedRoom;
  final VoidCallback onClose;
  final ValueChanged<RoomPostSummary> onSelect;
  final ValueChanged<String> onDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      child: Column(
        children: [
          const Spacer(),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Danh sách phòng trọ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${rooms.length} phòng phù hợp'),
                    trailing: IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (_, i) {
                        final room = rooms[i];
                        final selected = selectedRoom?.id == room.id;
                        return Material(
                          color: selected ? SacoColors.sacoOrange : Colors.white,
                          child: InkWell(
                            onTap: () => onSelect(room),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: room.imageUrl != null
                                        ? Image.network(
                                            room.imageUrl!,
                                            width: 56,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 56,
                                            height: 48,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.home_outlined),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          room.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: selected ? Colors.white : SacoColors.sacoBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          mapListPrice(room.price),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: selected ? Colors.white : SacoColors.sacoOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (selectedRoom != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton(
                        onPressed: () => onDetail(selectedRoom!.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: SacoColors.sacoOrange,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Xem chi tiết'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

