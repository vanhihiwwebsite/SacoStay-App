import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/utils/lifestyle_display.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/tenant_room_form.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/lifestyle_repository.dart';
import '../../repositories/tenant_room_repository.dart';
import 'widgets/tenant_room_details_form.dart';

class TenantRoomProfileScreen extends ConsumerStatefulWidget {
  const TenantRoomProfileScreen({super.key, this.returnUrl});

  final String? returnUrl;

  @override
  ConsumerState<TenantRoomProfileScreen> createState() =>
      _TenantRoomProfileScreenState();
}

class _TenantRoomProfileScreenState extends ConsumerState<TenantRoomProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _notEligible = false;
  String? _deletingImageUrl;
  TenantRoomProfileForm _form = emptyTenantRoomProfileForm();
  List<String> _existingImages = [];
  final List<String> _pendingImagePaths = [];
  static const _maxImages = 10;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      if (mounted) {
        context.go('/login?returnUrl=${Uri.encodeComponent('/tenant-room-profile')}');
      }
      return;
    }

    try {
      final answers = await ref.read(lifestyleRepositoryProvider).getMyAnswers();
      if (!hasRoomFromAnswers(answers)) {
        setState(() {
          _notEligible = true;
          _loading = false;
        });
        return;
      }
      final profile = await ref.read(tenantRoomRepositoryProvider).getMyProfile();
      if (profile != null) {
        _form = TenantRoomProfileForm(
          city: profile.city ?? 'all',
          district: profile.district ?? 'all',
          maxPeople: profile.maxPeople ?? 2,
          priceInput: formatTenantRoomPriceInput(profile.price),
          amenities: List<String>.from(profile.amenities),
          extraNotes: profile.extraNotes ?? '',
        );
        _existingImages = List<String>.from(profile.images);
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _notEligible = true;
        _loading = false;
      });
    }
  }

  int get _totalImageCount => _existingImages.length + _pendingImagePaths.length;

  bool get _canAddMoreImages => _totalImageCount < _maxImages;

  String _returnTarget() {
    final raw = widget.returnUrl?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return '/profile/me';
  }

  Future<void> _pickImages() async {
    final slots = _maxImages - _totalImageCount;
    if (slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tối đa $_maxImages ảnh.')),
      );
      return;
    }
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final accepted = picked.take(slots).map((x) => x.path).toList();
    setState(() => _pendingImagePaths.addAll(accepted));
    if (accepted.length < picked.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chỉ thêm được tối đa $slots ảnh nữa.')),
      );
    }
  }

  Future<void> _deleteExistingImage(String imageUrl) async {
    if (_deletingImageUrl != null) return;
    setState(() => _deletingImageUrl = imageUrl);
    try {
      final result = await ref.read(tenantRoomRepositoryProvider).deleteImage(imageUrl);
      setState(() {
        _existingImages = result.profile?.images ?? _existingImages.where((u) => u != imageUrl).toList();
        _deletingImageUrl = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (e) {
      setState(() => _deletingImageUrl = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa ảnh: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!isTenantRoomProfileComplete(_form)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa điểm và số người tối đa.')),
      );
      return;
    }
    final priceInput = _form.priceInput.trim();
    final price = parseTenantRoomPriceInput(priceInput);
    if (priceInput.isNotEmpty && price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá thuê không hợp lệ. Vui lòng nhập số VND (VD: 3000000).')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ref.read(tenantRoomRepositoryProvider).save(
            payload: tenantRoomProfilePayload(_form),
            imagePaths: _pendingImagePaths,
          );
      setState(() {
        _saving = false;
        _pendingImagePaths.clear();
        if (result.profile?.images != null) {
          _existingImages = List<String>.from(result.profile!.images);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
        context.go(_returnTarget());
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notEligible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chưa áp dụng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Trang này dành cho người đã có phòng trọ. Bạn có thể cập nhật lại trong trắc nghiệm lối sống.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/profile/me'),
                child: const Text('Về trang cá nhân'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thông tin phòng trọ',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Điền địa điểm, số người và tiện nghi để người tìm bạn hiểu rõ hơn về căn trọ bạn đang thuê.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TenantRoomDetailsForm(
                  form: _form,
                  onChanged: (f) => setState(() => _form = f),
                ),
                const Divider(height: 32),
                const Text(
                  'Ảnh phòng trọ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tối đa $_maxImages ảnh. Ảnh mới sẽ upload sau khi lưu thông tin.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                if (_existingImages.isNotEmpty || _pendingImagePaths.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _existingImages.length + _pendingImagePaths.length,
                    itemBuilder: (_, i) {
                      if (i < _existingImages.length) {
                        final url = resolveMediaUrl(_existingImages[i]);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(url, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: _deletingImageUrl == _existingImages[i]
                                    ? null
                                    : () => _deleteExistingImage(_existingImages[i]),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      final path = _pendingImagePaths[i - _existingImages.length];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(path), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => setState(() => _pendingImagePaths.remove(path)),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                if (_canAddMoreImages) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Thêm ảnh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SacoColors.sacoOrange,
                      side: BorderSide(color: Colors.orange.shade200),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: SacoColors.sacoOrange,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_saving ? 'Đang lưu…' : 'Lưu thông tin phòng'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go(_returnTarget()),
                  child: const Text('Để sau'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
