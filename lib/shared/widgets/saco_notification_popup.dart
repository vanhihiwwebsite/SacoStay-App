import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../repositories/notification_repository.dart';

/// Web-style notification dropdown (popover) anchored near the bell icon.
Future<void> showSacoNotificationPopup(
  BuildContext context,
  WidgetRef ref, {
  Offset? anchorOffset,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;

  final screen = MediaQuery.sizeOf(context);
  final top = (anchorOffset?.dy ?? (MediaQuery.paddingOf(context).top + 52));
  final right = 12.0;
  final width = (screen.width - 24).clamp(280.0, 360.0);

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Thông báo',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) {
      return Stack(
        children: [
          Positioned(
            top: top,
            right: right,
            width: width,
            child: Material(
              color: Colors.transparent,
              child: _NotificationPanel(
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

class _NotificationPanel extends ConsumerWidget {
  const _NotificationPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final dateFmt = DateFormat('dd-MM');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thông báo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: SacoColors.sacoBlue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Lỗi: $e', style: const TextStyle(fontSize: 13)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Không có thông báo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SacoColors.sacoGray),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.grey.shade100,
                  ),
                  itemBuilder: (context, index) {
                    final n = items[index];
                    return InkWell(
                      onTap: () async {
                        if (!n.isRead) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead(n.id);
                          ref.invalidate(notificationsListProvider);
                          ref.invalidate(unreadNotificationCountProvider);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(
                                fontWeight:
                                    n.isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 14,
                                color: SacoColors.sacoBlue,
                              ),
                            ),
                            if (n.body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (n.createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                dateFmt.format(n.createdAt!.toLocal()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (async.valueOrNull?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: TextButton(
                onPressed: () async {
                  await ref.read(notificationRepositoryProvider).markAllRead();
                  ref.invalidate(notificationsListProvider);
                  ref.invalidate(unreadNotificationCountProvider);
                },
                style: TextButton.styleFrom(
                  foregroundColor: SacoColors.sacoOrange,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Đánh dấu tất cả đã đọc'),
              ),
            ),
        ],
      ),
    );
  }
}
