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

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final _picker = ImagePicker();
  int _step = 1;
  bool _statusLoading = true;
  bool _submitting = false;
  String? _error;
  String? _adminNote;
  KycApiStatus _status = KycApiStatus.notSubmitted;

  String? _frontPath;
  String? _backPath;
  String? _videoPath;

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
    final status = await ref.read(kycRepositoryProvider).getMyStatus();
    if (status.isApproved) {
      _continueAfterVerification();
      return;
    }
    if (status.isPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hồ sơ đang được xử lý.')),
        );
        _continueAfterVerification();
      }
      return;
    }
    setState(() {
      _status = status.status;
      _adminNote = status.adminNote;
      _statusLoading = false;
    });
  }

  void _continueAfterVerification() {
    final returnUrl =
        GoRouterState.of(context).uri.queryParameters['returnUrl'] ?? '/profile-setup';
    context.go(returnUrl);
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
    setState(() => _videoPath = file.path);
  }

  Future<void> _submit() async {
    if (_frontPath == null || _backPath == null || _videoPath == null) {
      setState(() => _error = 'Vui lòng tải đủ ảnh CCCD và video selfie.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final msg = await ref.read(kycRepositoryProvider).submit(
            frontIdPath: _frontPath!,
            backIdPath: _backPath!,
            selfieVideoPath: _videoPath!,
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _continueAfterVerification();
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
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
            kycStatusLabel(_status),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_adminNote != null && _adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú: $_adminNote',
              style: const TextStyle(color: Colors.orange),
            ),
          ],
          const SizedBox(height: 24),
          if (_step == 1) ...[
            const Text('Bước 1: Ảnh CCCD', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  ? () => setState(() => _step = 2)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: SacoColors.sacoOrange),
              child: const Text('Tiếp tục'),
            ),
          ] else ...[
            const Text('Bước 2: Video selfie (~6 giây)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.videocam),
              label: Text(_videoPath != null ? 'Video đã chọn ✓' : 'Quay / chọn video'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_submitting ? 'Đang gửi…' : 'Gửi xác minh'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Quay lại bước 1'),
            ),
          ],
        ],
      ),
    );
  }
}
