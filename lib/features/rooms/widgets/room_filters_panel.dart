import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../core/utils/room_amenities.dart';
import '../../../core/utils/vietnam_districts.dart';
import '../../../models/room_post.dart';

class RoomFiltersPanel extends StatelessWidget {
  const RoomFiltersPanel({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClose,
    this.resultCount = 0,
    this.scrollable = false,
  });

  final RoomListFilters filters;
  final ValueChanged<RoomListFilters> onChanged;
  final VoidCallback onClose;
  final int resultCount;
  /// When true, body scrolls inside a bounded height (map popup).
  final bool scrollable;

  static const _selectedBg = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final districts = districtFilterOptions(filters.city);
    final fields = _buildFields(districts);

    final body = scrollable
        ? Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: fields,
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(20),
            child: fields,
          );

    return Container(
      margin: scrollable ? null : const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Bộ lọc tìm kiếm',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          body,
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onChanged(RoomListFilters()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Bỏ chọn'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onClose,
                    style: FilledButton.styleFrom(
                      backgroundColor: SacoColors.sacoOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Xem kết quả ($resultCount)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFields(List<FilterChipOption> districts) {
    final districtValue = districts.any((d) => d.value == filters.district)
        ? filters.district
        : 'all';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Thành phố'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filterCityOptions.map((opt) {
            final selected = filters.city == opt.value;
            return _filterChip(
              label: opt.label,
              selected: selected,
              onTap: () {
                final next = filters.copy();
                next.city = opt.value;
                if (opt.value != filters.city) {
                  next.district = 'all';
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Quận/Huyện'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('district-${filters.city}-$districtValue'),
          initialValue: districtValue,
          decoration: _inputDecoration(),
          items: districts
              .map(
                (d) => DropdownMenuItem(value: d.value, child: Text(d.label)),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            final next = filters.copy();
            next.district = v;
            onChanged(next);
          },
        ),
        const SizedBox(height: 20),
        _sectionTitle('Giá (triệu VNĐ)'),
        const SizedBox(height: 4),
        Text(
          '${(filters.priceMin / 1000000).toStringAsFixed(1)}tr — ${(filters.priceMax / 1000000).toStringAsFixed(1)}tr',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        RangeSlider(
          values: RangeValues(
            filters.priceMin.toDouble(),
            filters.priceMax.toDouble(),
          ),
          min: priceSliderMin.toDouble(),
          max: priceSliderMax.toDouble(),
          divisions: 100,
          activeColor: SacoColors.sacoOrange,
          onChanged: (range) {
            final next = filters.copy();
            next.priceMin = range.start.round();
            next.priceMax = range.end.round();
            onChanged(next);
          },
        ),
        const SizedBox(height: 12),
        _sectionTitle('Số người ở'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: maxOccupantOptions.map((opt) {
            final selected = filters.maxOccupants == opt.value;
            return _filterChip(
              label: opt.label,
              selected: selected,
              onTap: () {
                final next = filters.copy();
                next.maxOccupants = opt.value;
                onChanged(next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Tiện ích'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roomFilterAmenityOptions.map((opt) {
            final selected = isRoomFilterAmenitySelected(filters.amenities, opt.value);
            return _filterChip(
              label: opt.label,
              selected: selected,
              onTap: () {
                final next = filters.copy();
                applyAmenityToggle(next, opt.value, !selected);
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _selectedBg : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
