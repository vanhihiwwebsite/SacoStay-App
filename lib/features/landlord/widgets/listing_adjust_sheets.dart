import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../core/utils/listing_display.dart';
import '../../../models/room_post.dart';
import '../../../repositories/room_post_repository.dart';

/// Center dialog to edit occupancy + display status — mirrors web mobile.
Future<bool> showListingEditDialog({
  required BuildContext context,
  required RoomPostSummary post,
  required RoomPostRepository repository,
}) async {
  final maxPeople = post.maxPeople ?? 1;
  var current = (post.currentPeople ?? 0).clamp(0, maxPeople);
  var active = _isActiveStatus(post.status);
  var saving = false;

  final saved = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black45,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Điều chỉnh tin đăng',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: SacoColors.sacoBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SacoColors.sacoOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SacoColors.sacoOrange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Sức chứa tối đa: $maxPeople người (đặt khi đăng tin, không đổi tại đây)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Số người đang ở trong căn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CounterButton(
                        icon: Icons.remove,
                        enabled: current > 0 && !saving,
                        onTap: () => setLocal(() => current -= 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            children: [
                              TextSpan(
                                text: '$current',
                                style: const TextStyle(color: SacoColors.sacoOrange),
                              ),
                              TextSpan(
                                text: '/$maxPeople',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _CounterButton(
                        icon: Icons.add,
                        enabled: current < maxPeople && !saving,
                        onTap: () => setLocal(() => current += 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ví dụ: 0/$maxPeople = chưa có người thuê thêm · 1/$maxPeople = đã có 1 người.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trạng thái hiển thị',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<bool>(
                        isExpanded: true,
                        value: active,
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text('Đang hiển thị (active)'),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Tạm ẩn (inactive)'),
                          ),
                        ],
                        onChanged: saving ? null : (v) => setLocal(() => active = v ?? true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chọn inactive để tạm ẩn tin khỏi danh sách công khai.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.35),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setLocal(() => saving = true);
                                try {
                                  await repository.updateStatus(
                                    post.id,
                                    active ? 'active' : 'hidden',
                                    currentPeople: current,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } catch (e) {
                                  setLocal(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Lỗi: $e')),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: SacoColors.sacoOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Lưu thay đổi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return saved == true;
}

bool _isActiveStatus(String? status) => isListingActive(status);

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? Colors.grey.shade400 : Colors.grey.shade200,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
