import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../core/utils/lifestyle_display.dart';
import '../../../core/utils/tenant_room_form.dart';
import '../../../core/utils/vietnam_districts.dart';

class TenantRoomDetailsForm extends StatefulWidget {
  const TenantRoomDetailsForm({
    super.key,
    required this.form,
    required this.onChanged,
    this.compact = false,
  });

  final TenantRoomProfileForm form;
  final ValueChanged<TenantRoomProfileForm> onChanged;
  final bool compact;

  @override
  State<TenantRoomDetailsForm> createState() => _TenantRoomDetailsFormState();
}

class _TenantRoomDetailsFormState extends State<TenantRoomDetailsForm> {
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.form.priceInput);
    _notesController = TextEditingController(text: widget.form.extraNotes);
  }

  @override
  void didUpdateWidget(covariant TenantRoomDetailsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.form.priceInput != widget.form.priceInput &&
        _priceController.text != widget.form.priceInput) {
      _priceController.text = widget.form.priceInput;
    }
    if (oldWidget.form.extraNotes != widget.form.extraNotes &&
        _notesController.text != widget.form.extraNotes) {
      _notesController.text = widget.form.extraNotes;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _patch(TenantRoomProfileForm next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final pricePreview = tenantRoomPriceLabel(parseTenantRoomPriceInput(form.priceInput));
    final districts = districtFilterOptions(form.city);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Địa điểm', 'Chọn thành phố và quận/huyện nơi bạn đang thuê'),
        _chipRow(
          filterCityOptions,
          form.city,
          (v) => _patch(TenantRoomProfileForm(
            city: v,
            district: 'all',
            maxPeople: form.maxPeople,
            priceInput: form.priceInput,
            amenities: form.amenities,
            extraNotes: form.extraNotes,
          )),
        ),
        if (form.city != 'all') ...[
          const SizedBox(height: 8),
          _chipRow(
            districts,
            form.district,
            (v) => _patch(TenantRoomProfileForm(
              city: form.city,
              district: v,
              maxPeople: form.maxPeople,
              priceInput: form.priceInput,
              amenities: form.amenities,
              extraNotes: form.extraNotes,
            )),
          ),
        ],
        const SizedBox(height: 20),
        _sectionTitle('Số người tối đa', null),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tenantRoomMaxPeopleOptions.map((opt) {
            return _chip(
              opt.label,
              form.maxPeople == opt.value,
              () => _patch(TenantRoomProfileForm(
                city: form.city,
                district: form.district,
                maxPeople: opt.value,
                priceInput: form.priceInput,
                amenities: form.amenities,
                extraNotes: form.extraNotes,
              )),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Giá tiền trọ', 'Nhập giá thuê bằng số VND/tháng (VD: 3000000)'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  hintText: '3000000',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _patch(TenantRoomProfileForm(
                  city: form.city,
                  district: form.district,
                  maxPeople: form.maxPeople,
                  priceInput: v,
                  amenities: form.amenities,
                  extraNotes: form.extraNotes,
                )),
              ),
            ),
            const SizedBox(width: 8),
            const Text('đ/tháng'),
          ],
        ),
        if (pricePreview.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Hiển thị: $pricePreview', style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 20),
        _sectionTitle('Tiện nghi', 'Chọn các tiện nghi có trong phòng (có thể chọn nhiều)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tenantRoomAmenityOptions.map((opt) {
            final selected = form.amenities.contains(opt.value);
            return FilterChip(
              label: Text('${opt.icon} ${opt.value}'),
              selected: selected,
              onSelected: (_) {
                final next = List<String>.from(form.amenities);
                if (selected) {
                  next.remove(opt.value);
                } else {
                  next.add(opt.value);
                }
                _patch(TenantRoomProfileForm(
                  city: form.city,
                  district: form.district,
                  maxPeople: form.maxPeople,
                  priceInput: form.priceInput,
                  amenities: next,
                  extraNotes: form.extraNotes,
                ));
              },
              selectedColor: SacoColors.sacoOrange.withValues(alpha: 0.2),
              checkmarkColor: SacoColors.sacoOrange,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Thông tin thêm (tuỳ chọn)', null),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: gần trường, có ban công nhỏ, cho nuôi mèo...',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _patch(TenantRoomProfileForm(
            city: form.city,
            district: form.district,
            maxPeople: form.maxPeople,
            priceInput: form.priceInput,
            amenities: form.amenities,
            extraNotes: v,
          )),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String? hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (hint != null)
            Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _chipRow(
    List<FilterChipOption> options,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((opt) => _chip(opt.label, selected == opt.value, () => onSelect(opt.value)))
          .toList(),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: active ? SacoColors.sacoOrange : Colors.white,
      labelStyle: TextStyle(
        color: active ? Colors.white : Colors.black87,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: active ? SacoColors.sacoOrange : Colors.grey.shade300),
    );
  }
}
