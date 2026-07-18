import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/user_display.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/report_repository.dart';

enum ReportTargetType { room, user }

Future<void> showReportModal(
  BuildContext context, {
  required ReportTargetType type,
  required String targetName,
  String? reportedRoomId,
  String? reportedUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ReportModalSheet(
        type: type,
        targetName: targetName,
        reportedRoomId: reportedRoomId,
        reportedUserId: reportedUserId,
      ),
    ),
  );
}

class ReportModalSheet extends ConsumerStatefulWidget {
  const ReportModalSheet({
    super.key,
    required this.type,
    required this.targetName,
    this.reportedRoomId,
    this.reportedUserId,
  });

  final ReportTargetType type;
  final String targetName;
  final String? reportedRoomId;
  final String? reportedUserId;

  @override
  ConsumerState<ReportModalSheet> createState() => _ReportModalSheetState();
}

class _ReportModalSheetState extends ConsumerState<ReportModalSheet> {
  final _detailsController = TextEditingController();
  final _picker = ImagePicker();
  final _selectedReasons = <String>{};
  final _imagePaths = <String>[];
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  List<String> get _reasons =>
      widget.type == ReportTargetType.room ? roomReportReasons : userReportReasons;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imagePaths.length >= kMaxReportImages) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final err = validateReportImagePath(file.path);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _imagePaths.add(file.path);
    });
  }

  Future<void> _submit() async {
    if (_selectedReasons.isEmpty) {
      setState(() => _error = 'Vui lòng chọn ít nhất một lý do.');
      return;
    }

    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      setState(() => _error = 'Vui lòng đăng nhập để gửi báo cáo.');
      return;
    }

    final reporterId = userIdFromUser(auth.user?.raw);
    if (reporterId == null) {
      setState(() => _error = 'Không xác định được tài khoản. Vui lòng đăng nhập lại.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(reportRepositoryProvider).submit(
            reporterId: reporterId,
            reasons: _selectedReasons.toList(),
            description: _detailsController.text,
            reportedRoomId: widget.type == ReportTargetType.room
                ? widget.reportedRoomId
                : null,
            reportedUserId: widget.type == ReportTargetType.user
                ? widget.reportedUserId
                : null,
            imagePaths: _imagePaths,
          );
      if (mounted) setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gửi báo cáo thất bại. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 56, color: Colors.green.shade600),
            const SizedBox(height: 16),
            const Text(
              'Đã gửi báo cáo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản trị viên sẽ xem xét báo cáo của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: SacoColors.sacoOrange,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Báo cáo: ${widget.targetName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn lý do (có thể chọn nhiều)',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((reason) {
                  final selected = _selectedReasons.contains(reason);
                  return FilterChip(
                    label: Text(reason, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedReasons.remove(reason);
                        } else {
                          _selectedReasons.add(reason);
                        }
                      });
                    },
                    selectedColor: SacoColors.sacoOrange.withValues(alpha: 0.2),
                    checkmarkColor: SacoColors.sacoOrange,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mô tả thêm (tuỳ chọn)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ảnh minh chứng (tối đa $kMaxReportImages, mỗi ảnh 5MB)',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._imagePaths.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(entry.value),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagePaths.removeAt(entry.key)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_imagePaths.length < kMaxReportImages)
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('Thêm ảnh'),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (!ref.read(authControllerProvider).isLoggedIn) {
                          Navigator.pop(context);
                          context.go(
                            '/login?returnUrl=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
                          );
                          return;
                        }
                        _submit();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: SacoColors.sacoOrange,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_submitting ? 'Đang gửi…' : 'Gửi báo cáo'),
              ),
            ],
          ),
        );
      },
    );
  }
}
