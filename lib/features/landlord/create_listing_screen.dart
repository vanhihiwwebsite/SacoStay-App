import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme.dart';
import '../../core/utils/vietnam_districts.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/room_amenities.dart';
import '../../repositories/room_post_repository.dart';
import '../../shared/widgets/saco_landlord_ui.dart';
import 'widgets/map_pin_picker.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();
  final _area = TextEditingController();
  final _maxOccupants = TextEditingController(text: '2');
  final _description = TextEditingController();

  String _city = 'Hà Nội';
  String? _district;
  LatLng _pin = const LatLng(21.0285, 105.8542);
  final _selectedAmenities = <String>{};
  final _imagePaths = <String>[];
  bool _submitting = false;

  static const _amenityOptions = landlordAmenityValues;

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _price.dispose();
    _area.dispose();
    _maxOccupants.dispose();
    _description.dispose();
    super.dispose();
  }

  List<String> get _districts =>
      _city == 'TP.HCM' ? hcmDistricts : hanoiDistricts;

  void _onCityChanged(String? city) {
    if (city == null) return;
    setState(() {
      _city = city;
      _district = null;
      _pin = city == 'TP.HCM'
          ? const LatLng(10.7769, 106.7009)
          : const LatLng(21.0285, 105.8542);
    });
  }

  Future<void> _pickImages() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if (_imagePaths.length >= 5) break;
        _imagePaths.add(f.path);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_district == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn quận/huyện')),
      );
      return;
    }
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thêm ít nhất 1 ảnh phòng')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final id = await ref.read(roomPostRepositoryProvider).createListing(
            title: _title.text.trim(),
            detailedAddress: _address.text.trim(),
            district: _district!,
            city: _city,
            latitude: _pin.latitude,
            longitude: _pin.longitude,
            price: int.parse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')),
            area: double.parse(_area.text.replaceAll(',', '.')),
            maxOccupants: int.parse(_maxOccupants.text.trim()),
            description: _description.text.trim(),
            amenities: _selectedAmenities.toList(),
            imagePaths: _imagePaths,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng tin thành công!')),
      );
      context.go(id.isNotEmpty ? '/my-listings' : '/landlord-profile');
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? e.message
            : 'Lỗi đăng tin. Vui lòng kiểm tra lại thông tin.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SacoPageHeader(
              title: 'Đăng tin phòng trọ',
              subtitle: 'Tiếp cận hàng nghìn người tìm trọ mỗi ngày',
            ),
            SacoSectionCard(
              title: 'Thông tin cơ bản',
              child: Column(
                children: [
                  SacoFormField(
                    label: 'Tiêu đề tin đăng *',
                    child: TextFormField(
                      controller: _title,
                      decoration: sacoInputDecoration(
                        hintText: 'VD: Phòng trọ cao cấp gần ĐH Bách Khoa...',
                      ),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? 'Nhập tiêu đề (≥5 ký tự)'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SacoFormField(
                    label: 'Địa chỉ chi tiết *',
                    child: TextFormField(
                      controller: _address,
                      decoration: sacoInputDecoration(
                        hintText: 'Số nhà, tên đường...',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nhập địa chỉ' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SacoFormField(
                    label: 'Thành phố *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: sacoInputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'Hà Nội', child: Text('Hà Nội')),
                        DropdownMenuItem(value: 'TP.HCM', child: Text('TP.HCM')),
                      ],
                      onChanged: _onCityChanged,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SacoFormField(
                    label: 'Quận/Huyện *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _district,
                      decoration: sacoInputDecoration(),
                      items: _districts
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _district = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SacoFormField(
                    label: 'Diện tích (m²) *',
                    child: TextFormField(
                      controller: _area,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: sacoInputDecoration(hintText: '25'),
                      validator: (v) =>
                          (v == null || double.tryParse(v.replaceAll(',', '.')) == null)
                              ? 'Nhập diện tích'
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            SacoSectionCard(
              title: 'Giá & sức chứa',
              child: Column(
                children: [
                  SacoFormField(
                    label: 'Giá/tháng (VNĐ) *',
                    child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: sacoInputDecoration(hintText: '3000000'),
                      validator: (v) =>
                          (v == null || int.tryParse(v) == null) ? 'Nhập giá hợp lệ' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SacoFormField(
                    label: 'Số người tối đa *',
                    child: TextFormField(
                      controller: _maxOccupants,
                      keyboardType: TextInputType.number,
                      decoration: sacoInputDecoration(hintText: '2'),
                      validator: (v) =>
                          (v == null || int.tryParse(v) == null) ? 'Nhập số người' : null,
                    ),
                  ),
                ],
              ),
            ),
            SacoSectionCard(
              title: 'Mô tả & tiện ích',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SacoFormField(
                    label: 'Mô tả chi tiết *',
                    child: TextFormField(
                      controller: _description,
                      maxLines: 4,
                      decoration: sacoInputDecoration(
                        hintText: 'Mô tả không gian, nội thất, quy định...',
                      ),
                      validator: (v) => (v == null || v.trim().length < 20)
                          ? 'Mô tả ít nhất 20 ký tự'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tiện ích',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenityOptions.map((a) {
                      final selected = _selectedAmenities.contains(a);
                      return FilterChip(
                        label: Text(a),
                        selected: selected,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: SacoColors.sacoOrange,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedAmenities.add(a);
                            } else {
                              _selectedAmenities.remove(a);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SacoSectionCard(
              title: 'Vị trí trên bản đồ',
              subtitle: 'Chạm vào bản đồ để đặt ghim',
              child: MapPinPicker(
                initial: _pin,
                onChanged: (p) => setState(() => _pin = p),
              ),
            ),
            SacoSectionCard(
              title: 'Ảnh phòng *',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Thêm ảnh (tối đa 5)'),
                  ),
                  if (_imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagePaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_imagePaths[i]),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(24, 24),
                                ),
                                iconSize: 16,
                                onPressed: () => setState(() => _imagePaths.removeAt(i)),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SacoPrimaryButton(
                label: _submitting ? 'Đang đăng tin…' : 'Đăng tin ngay',
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
