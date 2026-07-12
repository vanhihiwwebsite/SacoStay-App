import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/media_url.dart';
import '../../features/auth/auth_provider.dart';
import '../../repositories/user_profile_images_repository.dart';

Future<void> showProfilePhotosModal(BuildContext context, WidgetRef ref) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Ảnh cá nhân',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.transparent,
            child: _ProfilePhotosPanel(
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
  );
}

class _ProfilePhotosPanel extends ConsumerStatefulWidget {
  const _ProfilePhotosPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_ProfilePhotosPanel> createState() => _ProfilePhotosPanelState();
}

class _ProfilePhotosPanelState extends ConsumerState<_ProfilePhotosPanel> {
  bool _loading = true;
  bool _uploading = false;
  String? _deletingUrl;
  List<String> _urls = [];
  static const _maxPhotos = UserProfileImagesRepository.maxPhotos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final urls = await ref.read(userProfileImagesRepositoryProvider).getMyImages();
      setState(() {
        _urls = urls;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  int get _remainingSlots => _maxPhotos - _urls.length;

  Future<void> _addPhotos() async {
    if (_remainingSlots <= 0) return;
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final paths = files.take(_remainingSlots).map((f) => f.path).toList();
      final uploaded = await ref.read(userProfileImagesRepositoryProvider).upload(paths);
      await ref.read(authControllerProvider.notifier).refreshProfile();
      setState(() {
        _urls = uploaded;
        _uploading = false;
      });
    } on ApiException catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(String url) async {
    if (_deletingUrl != null) return;
    setState(() => _deletingUrl = url);
    try {
      await ref.read(userProfileImagesRepositoryProvider).delete(url);
      await ref.read(authControllerProvider.notifier).refreshProfile();
      setState(() {
        _urls = _urls.where((u) => u != url).toList();
        _deletingUrl = null;
      });
    } on ApiException catch (e) {
      setState(() => _deletingUrl = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ảnh cá nhân',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tối đa $_maxPhotos ảnh — hiển thị trên thẻ tìm bạn',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 3 / 4,
                            ),
                            itemCount: _urls.length + (_remainingSlots > 0 ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i < _urls.length) {
                                final url = resolveMediaUrl(_urls[i]);
                                final deleting = _deletingUrl == _urls[i];
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(url, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: deleting ? null : () => _delete(_urls[i]),
                                          child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: deleting
                                                ? const Padding(
                                                    padding: EdgeInsets.all(8),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.delete_outline,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return InkWell(
                                onTap: _uploading ? null : _addPhotos,
                                borderRadius: BorderRadius.circular(12),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                      width: 2,
                                      strokeAlign: BorderSide.strokeAlignInside,
                                    ),
                                    color: SacoColors.pageBackground.withValues(alpha: 0.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_uploading)
                                        const CircularProgressIndicator(strokeWidth: 2)
                                      else ...[
                                        const Icon(
                                          Icons.add,
                                          size: 32,
                                          color: SacoColors.sacoOrange,
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Thêm ảnh',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: SacoColors.sacoOrange,
                                          ),
                                        ),
                                        Text(
                                          'Còn $_remainingSlots slot',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_urls.isEmpty && !_uploading) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có ảnh cá nhân. Thêm ảnh để hiển thị trên thẻ tìm bạn thay cho avatar mặc định.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
