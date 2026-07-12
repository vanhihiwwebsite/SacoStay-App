import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/kyc_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/kyc.dart';
import '../../repositories/kyc_repository.dart';

enum _EkycStep { idImages, faceVideo }

enum _SubmitState { idle, submitting, success, error }

/// eKYC: BE gọi FPT.AI khi submit — không chờ admin duyệt thủ công.
/// Thành công → `Approved` + `isVerified=true` ngay sau khi so khớp CCCD + video.
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final _picker = ImagePicker();
  _EkycStep _step = _EkycStep.idImages;
  _SubmitState _submitState = _SubmitState.idle;
  bool _statusLoading = true;
  bool _submitting = false;
  String? _error;
  String? _adminNote;
  String? _successMessage;
  KycApiStatus _status = KycApiStatus.notSubmitted;

  String? _frontPath;
  String? _backPath;
  String? _videoPath;

  String get _returnUrl =>
      GoRouterState.of(context).uri.queryParameters['returnUrl'] ?? '/profile-setup';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  Future<void> _loadStatus() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      setState(() => _statusLoading = false);
      return;
    }

    await ref.read(authControllerProvider.notifier).refreshProfile();
    final status = await ref.read(kycRepositoryProvider).getMyStatus();

    if (!mounted) return;

    if (status.isApproved) {
      _continueAfterVerification();
      return;
    }

    if (status.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hồ sơ xác thực đang được xử lý. Vui lòng thử lại sau.'),
        ),
      );
      _continueAfterVerification();
      return;
    }

    setState(() {
      _status = status.status;
      _adminNote = status.adminNote;
      _statusLoading = false;
      if (status.status == KycApiStatus.rejected ||
          status.status == KycApiStatus.needReupload) {
        _adminNote = status.adminNote;
      }
    });
  }

  void _continueAfterVerification() {
    if (!mounted) return;
    context.go(_returnUrl);
  }

  Future<void> _pickId(bool front) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      if (front) {
        _frontPath = file.path;
      } else {
        _backPath = file.path;
      }
    });
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 6),
    );
    if (file == null) return;
    setState(() {
      _videoPath = file.path;
      _submitState = _SubmitState.idle;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_frontPath == null || _backPath == null || _videoPath == null) {
      setState(() => _error = 'Vui lòng tải đủ ảnh CCCD và video selfie.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitState = _SubmitState.submitting;
      _error = null;
    });

    try {
      final msg = await ref.read(kycRepositoryProvider).submit(
            frontIdPath: _frontPath!,
            backIdPath: _backPath!,
            selfieVideoPath: _videoPath!,
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      final kyc = await ref.read(kycRepositoryProvider).getMyStatus();

      if (!mounted) return;

      if (kyc.isApproved) {
        setState(() {
          _submitting = false;
          _submitState = _SubmitState.success;
          _successMessage = msg.isNotEmpty ? msg : 'Khuôn mặt khớp với ảnh CCCD';
          _status = KycApiStatus.approved;
        });
        return;
      }

      if (kyc.isPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : 'Đã gửi hồ sơ xác thực.')),
        );
        _continueAfterVerification();
        return;
      }

      setState(() {
        _submitting = false;
        _submitState = _SubmitState.error;
        _error = kyc.adminNote ??
            msg.ifEmpty ??
            'Xác thực chưa thành công. Vui lòng thử lại.';
        _status = kyc.status;
        _adminNote = kyc.adminNote;
      });
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _submitState = _SubmitState.error;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _submitState = _SubmitState.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isLoggedIn) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/login?returnUrl=/identity-verification'),
          child: const Text('Đăng nhập để xác minh danh tính'),
        ),
      );
    }

    if (_statusLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xác thực danh tính eKYC',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Để đảm bảo an toàn cho cộng đồng, xác thực qua ảnh CCCD và quét khuôn mặt (FPT.AI).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            kycStatusLabel(_status),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
          if (_adminNote != null && _adminNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lần xác thực trước chưa đạt',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(_adminNote!, style: TextStyle(color: Colors.amber.shade900, fontSize: 13)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_step == _EkycStep.idImages) _buildStep1() else _buildStep2(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bước 1: Ảnh CCCD', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          'Tải ảnh mặt trước và mặt sau CCCD rõ nét (JPG/PNG, tối đa 5MB). Ảnh mặt trước cần thấy rõ ảnh chân dung trên thẻ.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickId(true),
                icon: const Icon(Icons.credit_card),
                label: Text(_frontPath != null ? 'Mặt trước ✓' : 'Mặt trước'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickId(false),
                icon: const Icon(Icons.credit_card_outlined),
                label: Text(_backPath != null ? 'Mặt sau ✓' : 'Mặt sau'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _frontPath != null && _backPath != null
              ? () => setState(() => _step = _EkycStep.faceVideo)
              : null,
          style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
          child: const Text('Tiếp tục bước 2'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bước 2: Quét khuôn mặt',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Quay video khuôn mặt khoảng 6 giây. Hệ thống sẽ so khớp với ảnh trên CCCD qua FPT.AI — không cần chờ admin duyệt.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_submitState == _SubmitState.success) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Xác thực thành công!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _successMessage ?? 'Khuôn mặt khớp với ảnh CCCD',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _continueAfterVerification,
            style: FilledButton.styleFrom(
              backgroundColor: SacoColors.sacoOrange,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Hoàn tất xác thực'),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickVideo,
            icon: const Icon(Icons.videocam),
            label: Text(_videoPath != null ? 'Video đã chọn ✓' : 'Quay video 6 giây'),
          ),
          if (_submitState == _SubmitState.submitting) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Đang xác thực với hệ thống AI…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_submitting || _videoPath == null) ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: SacoColors.sacoOrange,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_submitting ? 'Đang gửi…' : 'Gửi xác minh'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() {
                    _step = _EkycStep.idImages;
                    _submitState = _SubmitState.idle;
                    _error = null;
                  }),
          child: const Text('Quay lại bước 1'),
        ),
      ],
    );
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}
