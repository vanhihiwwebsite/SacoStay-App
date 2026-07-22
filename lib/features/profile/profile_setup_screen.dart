import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/json_normalize.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/kyc.dart';
import '../../repositories/kyc_repository.dart';
import '../../shared/widgets/tenant_sub_page_scaffold.dart';

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

  String _gender = 'male';
  String _job = 'student';
  DateTime? _dateOfBirth;
  bool _loading = true;
  bool _submitting = false;
  bool _avatarUploading = false;
  bool _avatarDeleting = false;
  String? _error;
  KycApiStatus _kycStatus = KycApiStatus.notSubmitted;
  String? _kycAdminNote;

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
        final dobRaw = profileDateOfBirthSeed(user);
        _dateOfBirth = DateTime.tryParse(dobRaw.length >= 10 ? dobRaw.substring(0, 10) : dobRaw);
        _gender = genderToFormValue(user['gender'] ?? user['Gender']);
        final job = strField(pickField(user, 'job', ['Job', 'occupation']));
        _job = _normalizeJob(job);
      }
      final kyc = await ref.read(kycRepositoryProvider).getMyStatus();
      setState(() {
        _kycStatus = kyc.status;
        _kycAdminNote = kyc.adminNote;
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
    super.dispose();
  }

  String get _avatarUrl {
    final user = ref.read(authControllerProvider).user?.raw;
    final label = navProfileLabel(user);
    return resolveUserAvatarUrl(user, displayName: label);
  }

  bool get _hasServerAvatar => profileAvatarFromRaw(ref.read(authControllerProvider).user?.raw) != null;

  String get _pageTitle {
    final user = ref.read(authControllerProvider).user?.raw;
    if (user == null) return 'Tạo hồ sơ của bạn';
    final hasBio = strField(pickField(user, 'bio', ['Bio'])).isNotEmpty;
    final hasDob = strField(pickField(user, 'dateOfBirth', ['DateOfBirth'])).isNotEmpty;
    final hasJob = strField(pickField(user, 'job', ['Job', 'occupation'])).isNotEmpty;
    return hasBio || hasDob || hasJob ? 'Chỉnh sửa hồ sơ' : 'Tạo hồ sơ của bạn';
  }

  static final _namePattern = RegExp(r"^[\p{L}\s'.-]+$", unicode: true);

  bool _isValidName(String value) => _namePattern.hasMatch(value.trim());

  bool _isValidPhone(String value) {
    final p = value.trim();
    if (p.isEmpty) return true;
    return RegExp(r'^[0-9]{10,11}$').hasMatch(p);
  }

  String _normalizeJob(String job) {
    const allowed = {'student', 'fresher', 'working'};
    final normalized = job.trim().toLowerCase();
    if (allowed.contains(normalized)) return normalized;
    return 'student';
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _avatarUploading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(avatarFilePath: file.path);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _deleteAvatar() async {
    final url = profileAvatarFromRaw(ref.read(authControllerProvider).user?.raw);
    if (url == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ảnh đại diện'),
        content: const Text('Xóa ảnh đại diện hiện tại?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _avatarDeleting = true);
    try {
      await ref.read(authRepositoryProvider).deleteProfileImage(url);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _avatarDeleting = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  String? _dobForApi() {
    if (_dateOfBirth == null) return null;
    final d = _dateOfBirth!;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      setState(() => _error = 'Họ và tên là bắt buộc.');
      return;
    }
    if (!_isValidName(_firstName.text) || !_isValidName(_lastName.text)) {
      setState(() => _error = 'Chỉ được dùng chữ cái, không số hoặc ký tự đặc biệt.');
      return;
    }
    if (!_isValidPhone(_phone.text)) {
      setState(() => _error = 'Số điện thoại phải có 10–11 chữ số.');
      return;
    }
    if (_dateOfBirth == null) {
      setState(() => _error = 'Vui lòng chọn ngày sinh.');
      return;
    }
    final now = DateTime.now();
    final age = now.year - _dateOfBirth!.year;
    if (_dateOfBirth!.isAfter(now)) {
      setState(() => _error = 'Ngày sinh không phù hợp.');
      return;
    }
    if (age < 16) {
      setState(() => _error = 'Bạn phải từ 16 tuổi trở lên.');
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
            dateOfBirth: _dobForApi(),
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
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/profile/me');
      }
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
    } finally {
      if (mounted && _submitting) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildBody(BuildContext context, {required bool isMobile}) {
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
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile) ...[
            Text(
              _pageTitle,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Cập nhật thông tin cá nhân của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
          ],
          _kycBanner(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _avatarSection(),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(child: _labeledField('Họ', _firstName)),
                    const SizedBox(width: 12),
                    Expanded(child: _labeledField('Tên', _lastName)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _dobField()),
                    const SizedBox(width: 12),
                    Expanded(child: _genderField()),
                  ],
                ),
                const SizedBox(height: 16),
                _jobField(),
                const SizedBox(height: 16),
                _labeledField('Số điện thoại', _phone, keyboard: TextInputType.phone),
                const SizedBox(height: 16),
                _labeledField('Khu vực sống', _livingArea, hint: 'VD: Cầu Giấy, Hà Nội'),
                const SizedBox(height: 16),
                _bioField(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go('/profile/me'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Quay lại'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: SacoColors.sacoOrange,
                          minimumSize: const Size(0, 48),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Lưu hồ sơ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return form;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final body = _buildBody(context, isMobile: isMobile);
    if (isMobile) {
      return TenantSubPageScaffold(title: _pageTitle, body: body);
    }
    return body;
  }

  Widget _kycBanner() {
    switch (_kycStatus) {
      case KycApiStatus.approved:
        return _bannerBox(
          color: Colors.green.shade50,
          border: Colors.green.shade200,
          icon: Icons.verified_user_outlined,
          iconColor: Colors.green.shade600,
          title: 'Đã xác thực danh tính',
          message: 'Bạn có thể sử dụng tất cả các tính năng của hệ thống.',
        );
      case KycApiStatus.pending:
        return _bannerBox(
          color: Colors.blue.shade50,
          border: Colors.blue.shade200,
          icon: Icons.hourglass_top_outlined,
          iconColor: Colors.blue.shade600,
          title: 'Đang xử lý xác thực',
          message: 'Hệ thống AI đang kiểm tra hồ sơ. Vui lòng thử lại sau vài phút.',
        );
      case KycApiStatus.rejected:
      case KycApiStatus.needReupload:
        return _bannerBox(
          color: Colors.red.shade50,
          border: Colors.red.shade200,
          icon: Icons.error_outline,
          iconColor: Colors.red.shade600,
          title: 'Xác thực chưa thành công',
          message: _kycAdminNote ??
              'Khuôn mặt không khớp với CCCD hoặc ảnh không hợp lệ. Vui lòng thử lại.',
          actionLabel: 'Xác thực lại',
          onAction: () => context.go('/identity-verification?returnUrl=/profile-setup'),
        );
      default:
        return _bannerBox(
          color: Colors.orange.shade50,
          border: Colors.orange.shade200,
          icon: Icons.warning_amber_outlined,
          iconColor: Colors.orange.shade600,
          title: 'Chưa xác thực danh tính',
          message:
              'Bạn cần xác thực danh tính (CCCD + quét khuôn mặt eKYC) để sử dụng đầy đủ tính năng.',
          actionLabel: 'Xác thực ngay',
          onAction: () => context.go('/identity-verification?returnUrl=/profile-setup'),
        );
    }
  }

  Widget _bannerBox({
    required Color color,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: iconColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(actionLabel, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarSection() {
    final busy = _avatarUploading || _avatarDeleting;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(_avatarUrl),
            ),
            if (busy)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ảnh đại diện', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'JPG, PNG hoặc WebP — tối đa 5MB',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : _pickAvatar,
                    style: FilledButton.styleFrom(
                      backgroundColor: SacoColors.sacoOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(_hasServerAvatar ? 'Đổi ảnh' : 'Tải ảnh lên'),
                  ),
                  if (_hasServerAvatar)
                    OutlinedButton(
                      onPressed: busy ? null : _deleteAvatar,
                      child: const Text('Xóa ảnh'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _dobField() {
    final label = _dateOfBirth != null
        ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}'
        : 'Chọn ngày sinh';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ngày sinh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDateOfBirth,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(label, style: TextStyle(color: Colors.grey.shade800)),
          ),
        ),
      ],
    );
  }

  Widget _genderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giới tính', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('gender-$_gender'),
          isExpanded: true,
          initialValue: _gender,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Nam')),
            DropdownMenuItem(value: 'female', child: Text('Nữ')),
            DropdownMenuItem(value: 'other', child: Text('Khác')),
          ],
          onChanged: (v) => setState(() => _gender = v ?? 'male'),
        ),
      ],
    );
  }

  Widget _jobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Công việc', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('job-$_job'),
          isExpanded: true,
          initialValue: _job,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: const [
            DropdownMenuItem(value: 'student', child: Text('Sinh viên')),
            DropdownMenuItem(value: 'fresher', child: Text('Mới đi làm (Fresher)')),
            DropdownMenuItem(value: 'working', child: Text('Đã đi làm')),
          ],
          onChanged: (v) => setState(() => _job = v ?? 'student'),
        ),
      ],
    );
  }

  Widget _bioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giới thiệu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: _bio,
          maxLines: 4,
          maxLength: _maxBio,
          decoration: InputDecoration(
            hintText: 'Giới thiệu ngắn...',
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            counterText: '${_bio.text.length}/$_maxBio',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
