import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/kyc_display.dart';
import '../../core/utils/kyc_upload.dart';
import '../../features/auth/auth_provider.dart';
import '../../models/kyc.dart';
import '../../repositories/kyc_repository.dart';
import 'widgets/ekyc_id_upload_card.dart';
import 'widgets/ekyc_liveness_camera.dart';

enum _EkycStep { idImages, faceVideo }

enum _SubmitState { idle, submitting, success, error }

/// eKYC: BE gọi FPT.AI khi submit — không chờ admin duyệt thủ công.
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final _picker = ImagePicker();
  final _cameraKey = GlobalKey<EkycLivenessCameraState>();

  _EkycStep _step = _EkycStep.idImages;
  _SubmitState _submitState = _SubmitState.idle;
  bool _statusLoading = true;
  bool _submitting = false;
  EkycCameraPhase _cameraPhase = EkycCameraPhase.idle;
  bool _cameraBusy = false;
  String? _error;
  String? _adminNote;
  String? _successMessage;
  KycApiStatus _status = KycApiStatus.notSubmitted;

  String? _frontPath;
  String? _backPath;

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

    final err = validateKycIdImagePath(file.path);
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    setState(() {
      if (front) {
        _frontPath = file.path;
      } else {
        _backPath = file.path;
      }
      _error = null;
    });
  }

  void _clearFront() => setState(() => _frontPath = null);
  void _clearBack() => setState(() => _backPath = null);

  Future<void> _onVideoRecorded(String path) async {
    setState(() {
      _error = null;
      _submitState = _SubmitState.idle;
    });
    await _submit(selfieVideoPath: path);
  }

  Future<void> _submit({required String selfieVideoPath}) async {
    if (_frontPath == null || _backPath == null) {
      setState(() => _error = 'Thiếu ảnh CCCD. Quay lại bước 1.');
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
            selfieVideoPath: selfieVideoPath,
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
        _error = getApiErrorMessage(e);
      });
    }
  }

  void _syncCameraUi() {
    final state = _cameraKey.currentState;
    setState(() {
      _cameraPhase = state?.phase ?? EkycCameraPhase.idle;
      _cameraBusy = state?.isBusy ?? false;
    });
  }

  void _retryScan() {
    setState(() {
      _submitState = _SubmitState.idle;
      _error = null;
    });
  }

  void _backToStep1() async {
    await _cameraKey.currentState?.stopPreview();
    setState(() {
      _step = _EkycStep.idImages;
      _submitState = _SubmitState.idle;
      _error = null;
      _cameraPhase = EkycCameraPhase.idle;
      _cameraBusy = false;
    });
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
              const SizedBox(height: 12),
              Text(
                'Để đảm bảo an toàn cho cộng đồng, xác thực qua ảnh CCCD và quét khuôn mặt (FPT.AI).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 10),
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
        const Text(
          'Bước 1: Tải ảnh CCCD / CMND',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Text(
            'Vui lòng tải ảnh mặt trước và mặt sau CCCD/CMND — rõ nét, không lóa/cắt góc. '
            'Ảnh mặt trước cần thấy rõ ảnh chân dung trên thẻ.',
            style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        EkycIdUploadCard(
          label: 'Mặt trước CCCD',
          imagePath: _frontPath,
          onPick: () => _pickId(true),
          onClear: _clearFront,
        ),
        const SizedBox(height: 12),
        EkycIdUploadCard(
          label: 'Mặt sau CCCD',
          imagePath: _backPath,
          onPick: () => _pickId(false),
          onClear: _clearBack,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _frontPath != null && _backPath != null
              ? () => setState(() {
                    _step = _EkycStep.faceVideo;
                    _submitState = _SubmitState.idle;
                    _error = null;
                  })
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: SacoColors.sacoOrange,
            minimumSize: const Size.fromHeight(48),
          ),
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
        const SizedBox(height: 12),
        Text(
          'Bật camera ngay trong app — hệ thống tự quay đúng 6 giây rồi gửi lên FPT.AI so khớp với ảnh CCCD.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 20),
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
          EkycLivenessCamera(
            key: _cameraKey,
            disabled: _submitting,
            recordSeconds: 6,
            previewHeightFactor: 0.50,
            onPhaseChanged: _syncCameraUi,
            onVideoRecorded: _onVideoRecorded,
            onError: (msg) {
              setState(() {
                _submitState = _SubmitState.error;
                _error = msg;
              });
            },
          ),
          const SizedBox(height: 28),
          if (_cameraPhase == EkycCameraPhase.idle) ...[
            FilledButton.icon(
              onPressed: (_submitting || _cameraBusy)
                  ? null
                  : () async {
                      await _cameraKey.currentState?.startPreview();
                      _syncCameraUi();
                    },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Bắt đầu quét khuôn mặt'),
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ] else if (_cameraPhase == EkycCameraPhase.preview) ...[
            FilledButton.icon(
              onPressed: (_submitting || _cameraBusy)
                  ? null
                  : () async {
                      await _cameraKey.currentState?.recordVideo();
                      _syncCameraUi();
                    },
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Quét ngay (6 giây)'),
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cameraBusy
                  ? null
                  : () async {
                      await _cameraKey.currentState?.stopPreview();
                      _syncCameraUi();
                    },
              child: const Text('Hủy camera'),
            ),
          ] else if (_cameraPhase == EkycCameraPhase.recording) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Đang quay video…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ],
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
            if (_submitState == _SubmitState.error) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _submitting ? null : _retryScan,
                child: const Text('Thử quét lại'),
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting ? null : _backToStep1,
            child: const Text('Quay lại bước 1'),
          ),
        ],
      ],
    );
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}
