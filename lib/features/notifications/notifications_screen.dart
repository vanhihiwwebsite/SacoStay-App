import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../repositories/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final dateFmt = DateFormat('dd/MM HH:mm');

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) {
        return Column(
          children: [
            if (items.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await ref.read(notificationRepositoryProvider).markAllRead();
                    ref.invalidate(notificationsListProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: const Text('Đánh dấu tất cả đã đọc'),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Không có thông báo'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(notificationsListProvider);
                        ref.invalidate(unreadNotificationCountProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = items[index];
                          return Material(
                            color: n.isRead ? Colors.white : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.orange.shade100),
                              ),
                              leading: Icon(
                                n.isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: n.isRead
                                    ? Colors.grey
                                    : SacoColors.sacoOrange,
                              ),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight:
                                      n.isRead ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (n.body.isNotEmpty) Text(n.body),
                                  if (n.createdAt != null)
                                    Text(
                                      dateFmt.format(n.createdAt!.toLocal()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                if (!n.isRead) {
                                  await ref
                                      .read(notificationRepositoryProvider)
                                      .markRead(n.id);
                                  ref.invalidate(notificationsListProvider);
                                  ref.invalidate(unreadNotificationCountProvider);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
