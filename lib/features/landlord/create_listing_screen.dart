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
      context.go(id.isNotEmpty ? '/my-listings' : '/profile/me');
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

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/my-listings');
    }
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    String? hintText,
  }) {
    return sacoInputDecoration(hintText: hintText).copyWith(
      prefixIcon: Icon(icon, size: 22, color: SacoColors.sacoOrange),
    );
  }

  static const _amenityEmoji = {
    'Điều hòa': '❄️',
    'Nóng lạnh': '🚿',
    'Máy giặt': '👕',
    'Ban công': '🌿',
    'Thang máy': '🛗',
    'Bếp riêng': '🍳',
    'Bảo vệ 24/7': '🛡️',
    'Chỗ để xe': '🏍️',
    'WiFi': '📶',
    'Tủ lạnh': '🧊',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CreateListingHeader(onBack: _goBack),
        Expanded(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SacoGradientBanner(
                    eyebrow: 'CHỦ TRỌ',
                    title: 'Đăng tin phòng trọ',
                    subtitle: 'Tiếp cận hàng nghìn người tìm trọ mỗi ngày',
                    action: Row(
                      children: [
                        _HeroStatChip(
                          icon: Icons.visibility_outlined,
                          label: 'Hiển thị trên bản đồ',
                        ),
                        const SizedBox(width: 8),
                        _HeroStatChip(
                          icon: Icons.verified_outlined,
                          label: 'Xác thực nhanh',
                        ),
                      ],
                    ),
                  ),
                  _ListingSectionCard(
                    icon: Icons.home_work_outlined,
                    iconColor: SacoColors.sacoOrange,
                    title: 'Thông tin cơ bản',
                    child: Column(
                      children: [
                        SacoFormField(
                          label: 'Tiêu đề tin đăng *',
                          child: TextFormField(
                            controller: _title,
                            decoration: _fieldDecoration(
                              icon: Icons.edit_outlined,
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
                            decoration: _fieldDecoration(
                              icon: Icons.location_on_outlined,
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
                            decoration: _fieldDecoration(
                              icon: Icons.location_city_outlined,
                            ),
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
                            decoration: _fieldDecoration(icon: Icons.map_outlined),
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
                            decoration: _fieldDecoration(
                              icon: Icons.square_foot_outlined,
                              hintText: '25',
                            ),
                            validator: (v) =>
                                (v == null || double.tryParse(v.replaceAll(',', '.')) == null)
                                    ? 'Nhập diện tích'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ListingSectionCard(
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF16A34A),
                    title: 'Giá & sức chứa',
                    child: Column(
                      children: [
                        SacoFormField(
                          label: 'Giá/tháng (VNĐ) *',
                          child: TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _fieldDecoration(
                              icon: Icons.attach_money_rounded,
                              hintText: '3000000',
                            ),
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
                            decoration: _fieldDecoration(
                              icon: Icons.people_outline,
                              hintText: '2',
                            ),
                            validator: (v) =>
                                (v == null || int.tryParse(v) == null) ? 'Nhập số người' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ListingSectionCard(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Mô tả & tiện ích',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SacoFormField(
                          label: 'Mô tả chi tiết *',
                          child: TextFormField(
                            controller: _description,
                            maxLines: 4,
                            decoration: _fieldDecoration(
                              icon: Icons.notes_outlined,
                              hintText: 'Mô tả không gian, nội thất, quy định...',
                            ),
                            validator: (v) => (v == null || v.trim().length < 20)
                                ? 'Mô tả ít nhất 20 ký tự'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.emoji_objects_outlined,
                                size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Tiện ích',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _amenityOptions.map((a) {
                            final selected = _selectedAmenities.contains(a);
                            final emoji = _amenityEmoji[a] ?? '✓';
                            return FilterChip(
                              avatar: CircleAvatar(
                                backgroundColor: selected
                                    ? SacoColors.sacoOrange.withValues(alpha: 0.15)
                                    : Colors.grey.shade100,
                                child: Text(emoji, style: const TextStyle(fontSize: 14)),
                              ),
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
                  _ListingSectionCard(
                    icon: Icons.map_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    title: 'Vị trí trên bản đồ',
                    subtitle: 'Chạm vào bản đồ để đặt ghim',
                    child: MapPinPicker(
                      initial: _pin,
                      onChanged: (p) => setState(() => _pin = p),
                    ),
                  ),
                  _ListingSectionCard(
                    icon: Icons.photo_camera_outlined,
                    iconColor: const Color(0xFFEC4899),
                    title: 'Ảnh phòng *',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImages,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: SacoColors.sacoOrange,
                            side: BorderSide(color: Colors.orange.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Thêm ảnh (tối đa 5)'),
                        ),
                        if (_imagePaths.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined,
                                    size: 20, color: Colors.grey.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Thêm ít nhất 1 ảnh để đăng tin',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
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
          ),
        ),
      ],
    );
  }
}

class _CreateListingHeader extends StatelessWidget {
  const _CreateListingHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.black87,
                  tooltip: 'Quay lại',
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_home_work_outlined,
                          size: 20, color: SacoColors.sacoOrange),
                      const SizedBox(width: 8),
                      const Text(
                        'Đăng tin phòng trọ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListingSectionCard extends StatelessWidget {
  const _ListingSectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
