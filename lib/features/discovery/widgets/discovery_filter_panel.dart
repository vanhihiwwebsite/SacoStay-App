import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../core/utils/discovery_filters.dart';

class DiscoveryFilterPanel extends StatefulWidget {
  const DiscoveryFilterPanel({
    super.key,
    required this.filters,
    required this.onApply,
    this.onClose,
  });

  final DiscoveryFilters filters;
  final ValueChanged<DiscoveryFilters> onApply;
  final VoidCallback? onClose;

  @override
  State<DiscoveryFilterPanel> createState() => _DiscoveryFilterPanelState();
}

class _DiscoveryFilterPanelState extends State<DiscoveryFilterPanel> {
  late DiscoveryFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 520),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Bộ lọc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _draft = defaultDiscoveryFilters),
                    child: const Text('Đặt lại'),
                  ),
                  if (widget.onClose != null)
                    IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              _sectionTitle('Giới tính'),
              Wrap(
                spacing: 8,
                children: [
                  _chip('Tất cả', _draft.gender == DiscoveryGenderFilter.all, () {
                    setState(() => _draft = _draft.copyWith(gender: DiscoveryGenderFilter.all));
                  }),
                  _chip('Nam', _draft.gender == DiscoveryGenderFilter.male, () {
                    setState(() => _draft = _draft.copyWith(gender: DiscoveryGenderFilter.male));
                  }),
                  _chip('Nữ', _draft.gender == DiscoveryGenderFilter.female, () {
                    setState(() => _draft = _draft.copyWith(gender: DiscoveryGenderFilter.female));
                  }),
                ],
              ),
              const SizedBox(height: 12),
              _sectionTitle('Tình trạng phòng'),
              Wrap(
                spacing: 8,
                children: [
                  _chip('Tất cả', _draft.hasRoom == DiscoveryHasRoomFilter.all, () {
                    setState(() => _draft = _draft.copyWith(hasRoom: DiscoveryHasRoomFilter.all));
                  }),
                  _chip('Có phòng', _draft.hasRoom == DiscoveryHasRoomFilter.yes, () {
                    setState(() => _draft = _draft.copyWith(hasRoom: DiscoveryHasRoomFilter.yes));
                  }),
                  _chip('Chưa có', _draft.hasRoom == DiscoveryHasRoomFilter.no, () {
                    setState(() => _draft = _draft.copyWith(hasRoom: DiscoveryHasRoomFilter.no));
                  }),
                ],
              ),
              if (_draft.hasRoom == DiscoveryHasRoomFilter.yes) ...[
                const SizedBox(height: 12),
                _sectionTitle('Giá phòng'),
                DropdownButtonFormField<DiscoveryRoomPriceFilter>(
                  initialValue: _draft.roomPrice,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: DiscoveryRoomPriceFilter.all, child: Text('Tất cả')),
                    DropdownMenuItem(value: DiscoveryRoomPriceFilter.under2m, child: Text('Dưới 2 triệu')),
                    DropdownMenuItem(value: DiscoveryRoomPriceFilter.twoTo3m, child: Text('2–3 triệu')),
                    DropdownMenuItem(value: DiscoveryRoomPriceFilter.threeTo5m, child: Text('3–5 triệu')),
                    DropdownMenuItem(value: DiscoveryRoomPriceFilter.over5m, child: Text('Trên 5 triệu')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _draft = _draft.copyWith(roomPrice: v));
                  },
                ),
              ],
              const SizedBox(height: 12),
              _sectionTitle('Độ tuổi tối đa: ${_draft.maxAge}'),
              Slider(
                value: _draft.maxAge.toDouble(),
                min: 18,
                max: 40,
                divisions: 22,
                activeColor: SacoColors.sacoOrange,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(maxAge: v.round())),
              ),
              _sectionTitle('Hòa hợp tối thiểu: ${_draft.minCompatibility}%'),
              Slider(
                value: _draft.minCompatibility.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: SacoColors.sacoOrange,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(minCompatibility: v.round())),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => widget.onApply(_draft),
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: SacoColors.sacoOrange,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
      onSelected: (_) => onTap(),
    );
  }
}
