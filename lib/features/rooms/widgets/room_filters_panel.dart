import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../core/utils/vietnam_districts.dart';
import '../../../models/room_post.dart';

class RoomFiltersPanel extends StatelessWidget {
  const RoomFiltersPanel({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClose,
    this.scrollable = false,
  });

  final RoomListFilters filters;
  final ValueChanged<RoomListFilters> onChanged;
  final VoidCallback onClose;
  /// When true, body scrolls inside a bounded height (map popup).
  final bool scrollable;

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
        ],
      ),
    );
  }

  Widget _buildFields(List<FilterChipOption> districts) {
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
            return ChoiceChip(
              label: Text(opt.label),
              selected: selected,
              selectedColor: SacoColors.sacoOrange.withValues(alpha: 0.15),
              onSelected: (_) {
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
          initialValue: districts.any((d) => d.value == filters.district)
              ? filters.district
              : 'all',
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
            return ChoiceChip(
              label: Text(opt.label),
              selected: selected,
              selectedColor: SacoColors.sacoOrange.withValues(alpha: 0.15),
              onSelected: (_) {
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
          children: amenityOptions.map((opt) {
            final selected = filters.amenities.contains(opt.value);
            return FilterChip(
              label: Text(opt.label),
              selected: selected,
              selectedColor: SacoColors.sacoOrange.withValues(alpha: 0.15),
              onSelected: (v) {
                final next = filters.copy();
                if (v) {
                  next.amenities.add(opt.value);
                } else {
                  next.amenities.remove(opt.value);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => onChanged(RoomListFilters()),
          child: const Text('Xóa tất cả bộ lọc'),
        ),
      ],
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
