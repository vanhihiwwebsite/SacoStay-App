import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/kyc_display.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/kyc.dart';
import '../../repositories/kyc_repository.dart';
import '../../repositories/user_profile_images_repository.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _picker = ImagePicker();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _livingArea = TextEditingController();
  final _bio = TextEditingController();
  final _dob = TextEditingController();

  String _gender = 'male';
  String _job = 'student';
  bool _loading = true;
  bool _submitting = false;
  bool _avatarUploading = false;
  String? _error;
  KycApiStatus _kycStatus = KycApiStatus.notSubmitted;
  List<String> _personalPhotos = [];

  static const _maxBio = 300;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).refreshProfile();
      final user = ref.read(authControllerProvider).user?.raw;
      if (user != null) {
        final names = profileFirstLastSeed(user);
        _firstName.text = names.firstName;
        _lastName.text = names.lastName;
        _phone.text = strField(pickField(user, 'phoneNumber', ['PhoneNumber']));
        _livingArea.text = profileLivingAreaSeed(user);
        _bio.text = strField(pickField(user, 'bio', ['Bio']));
        _dob.text = profileDateOfBirthSeed(user);
        _gender = genderToFormValue(user['gender'] ?? user['Gender']);
        final job = strField(pickField(user, 'job', ['Job', 'occupation']));
        if (job.isNotEmpty) _job = job;
      }
      final kyc = await ref.read(kycRepositoryProvider).getMyStatus();
      final photos = await ref.read(userProfileImagesRepositoryProvider).getMyImages();
      setState(() {
        _kycStatus = kyc.status;
        _personalPhotos = photos;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _livingArea.dispose();
    _bio.dispose();
    _dob.dispose();
    super.dispose();
  }

  String get _avatarUrl {
    final user = ref.read(authControllerProvider).user?.raw;
    final label = navProfileLabel(user);
    return resolveUserAvatarUrl(user, displayName: label);
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _avatarUploading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(avatarFilePath: file.path);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => _avatarUploading = false);
    }
  }

  Future<void> _addPhotos() async {
    if (_personalPhotos.length >= UserProfileImagesRepository.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 5 ảnh cá nhân.')),
      );
      return;
    }
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    try {
      final paths = files.map((f) => f.path).toList();
      final uploaded = await ref.read(userProfileImagesRepositoryProvider).upload(paths);
      setState(() => _personalPhotos = uploaded);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deletePhoto(String url) async {
    try {
      await ref.read(userProfileImagesRepositoryProvider).delete(url);
      setState(() => _personalPhotos = _personalPhotos.where((u) => u != url).toList());
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _submit() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      setState(() => _error = 'Họ và tên là bắt buộc.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phoneNumber: _phone.text.trim(),
            job: _job,
            livingArea: _livingArea.text.trim(),
            bio: _bio.text.trim(),
            dateOfBirth: _dob.text.trim(),
            gender: _gender,
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cập nhật hồ sơ thành công'),
          backgroundColor: SacoColors.sacoOrange,
        ),
      );
      context.go('/');
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isLoggedIn) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/login?returnUrl=/profile-setup'),
          child: const Text('Đăng nhập để chỉnh sửa hồ sơ'),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = auth.user?.raw;
    final pageTitle = hasBasicProfileFilled(user)
        ? 'Chỉnh sửa hồ sơ'
        : 'Tạo hồ sơ của bạn';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pageTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Cập nhật thông tin cá nhân của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'eKYC: ${kycStatusLabel(_kycStatus)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(_avatarUrl),
                ),
                if (_avatarUploading)
                  const Positioned.fill(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _avatarUploading ? null : _pickAvatar,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Đổi ảnh đại diện'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._personalPhotos.map(
                (url) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _deletePhoto(url),
                        child: const Icon(Icons.close, size: 18, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              if (_personalPhotos.length < UserProfileImagesRepository.maxPhotos)
                OutlinedButton.icon(
                  onPressed: _addPhotos,
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: const Text('Thêm ảnh'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _field('Họ', _firstName)),
              const SizedBox(width: 12),
              Expanded(child: _field('Tên', _lastName)),
            ],
          ),
          const SizedBox(height: 12),
          _field('Ngày sinh (yyyy-MM-dd)', _dob),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: _decoration('Giới tính'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Nam')),
              DropdownMenuItem(value: 'female', child: Text('Nữ')),
              DropdownMenuItem(value: 'other', child: Text('Khác')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _job,
            decoration: _decoration('Nghề nghiệp'),
            items: const [
              DropdownMenuItem(value: 'student', child: Text('Sinh viên')),
              DropdownMenuItem(value: 'fresher', child: Text('Fresher')),
              DropdownMenuItem(value: 'working', child: Text('Đã đi làm')),
            ],
            onChanged: (v) => setState(() => _job = v ?? 'student'),
          ),
          const SizedBox(height: 12),
          _field('Số điện thoại', _phone, keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _field('Khu vực sinh sống', _livingArea),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 4,
            maxLength: _maxBio,
            decoration: _decoration('Giới thiệu bản thân'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: SacoColors.sacoOrange,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Lưu hồ sơ'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/lifestyle-quiz?returnUrl=/profile-setup'),
            child: const Text('Thay đổi lối sống (quiz)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/identity-verification?returnUrl=/profile-setup'),
            child: const Text('Xác minh danh tính (eKYC)'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: _decoration(label),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
