import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera trước trong app — tự quay đúng [recordSeconds] giây (FPT.AI Liveness V3).
class EkycLivenessCamera extends StatefulWidget {
  const EkycLivenessCamera({
    super.key,
    required this.onVideoRecorded,
    required this.onError,
    this.disabled = false,
    this.recordSeconds = 6,
    this.previewHeightFactor = 0.48,
    this.onPhaseChanged,
  });

  final ValueChanged<String> onVideoRecorded;
  final ValueChanged<String> onError;
  final bool disabled;
  final int recordSeconds;
  final VoidCallback? onPhaseChanged;

  /// Chiều cao khung camera so với màn hình (dọc, cao hơn mặc định).
  final double previewHeightFactor;

  @override
  State<EkycLivenessCamera> createState() => EkycLivenessCameraState();
}

enum EkycCameraPhase { idle, preview, recording }

class EkycLivenessCameraState extends State<EkycLivenessCamera> {
  CameraController? _controller;
  EkycCameraPhase _phase = EkycCameraPhase.idle;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _busy = false;

  EkycCameraPhase get phase => _phase;
  bool get isBusy => _busy;

  void _notifyParent() {
    widget.onPhaseChanged?.call();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      await c.dispose();
    }
  }

  Future<void> startPreview() async {
    if (widget.disabled || _busy) return;
    setState(() => _busy = true);

    try {
      final granted = await _ensureCameraPermission();
      if (!granted) {
        widget.onError('Cần quyền camera để quét khuôn mặt. Vui lòng cấp quyền trong Cài đặt.');
        return;
      }

      await _disposeController();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        widget.onError('Không tìm thấy camera trên thiết bị.');
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _phase = EkycCameraPhase.preview;
      });
      _notifyParent();
    } catch (_) {
      widget.onError('Không mở được camera. Kiểm tra quyền truy cập và thử lại.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _notifyParent();
      }
    }
  }

  Future<void> recordVideo() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    if (_phase == EkycCameraPhase.recording) return;

    setState(() {
      _busy = true;
      _phase = EkycCameraPhase.recording;
      _countdown = widget.recordSeconds;
    });
    _notifyParent();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      }
    });

    try {
      await controller.startVideoRecording();
      await Future<void>.delayed(Duration(seconds: widget.recordSeconds));
      final file = await controller.stopVideoRecording();
      _countdownTimer?.cancel();

      if (!mounted) return;

      await _disposeController();
      setState(() {
        _phase = EkycCameraPhase.idle;
        _countdown = 0;
      });
      _notifyParent();

      widget.onVideoRecorded(file.path);
    } catch (_) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _phase = EkycCameraPhase.preview;
          _countdown = 0;
        });
        _notifyParent();
      }
      widget.onError('Không quay được video ${widget.recordSeconds} giây. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _notifyParent();
      }
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> stopPreview() async {
    _countdownTimer?.cancel();
    await _disposeController();
    if (mounted) {
      setState(() {
        _phase = EkycCameraPhase.idle;
        _countdown = 0;
      });
      _notifyParent();
    }
  }

  Widget buildPreviewViewport(BuildContext context) {
    final controller = _controller;
    final previewReady =
        controller != null && controller.value.isInitialized && _phase != EkycCameraPhase.idle;
    final previewHeight = MediaQuery.sizeOf(context).height * widget.previewHeightFactor;

    return SizedBox(
      height: previewHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: previewReady
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _PortraitCameraPreview(controller: controller),
                    if (_phase == EkycCameraPhase.recording)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_countdown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Giữ khuôn mặt trong khung hình',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face_retouching_natural, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Camera sẽ hiển thị tại đây',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildPreviewViewport(context);
  }
}

/// Crop preview camera thành khung dọc (tránh bị ngang quá trên điện thoại).
class _PortraitCameraPreview extends StatelessWidget {
  const _PortraitCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        final w = previewSize?.height ?? constraints.maxWidth;
        final h = previewSize?.width ?? constraints.maxHeight;

        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: w,
            height: h,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }
}
