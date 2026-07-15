import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/kyc_upload.dart';

/// Ô upload ảnh CCCD — preview + xóa, giống web.
class EkycIdUploadCard extends StatelessWidget {
  const EkycIdUploadCard({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final borderColor = hasImage ? Colors.green.shade400 : Colors.grey.shade300;
    final bgColor = hasImage ? Colors.green.shade50 : Colors.grey.shade50;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hasImage ? _buildSelected(context) : _buildEmpty(context),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            child: Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'JPG, PNG – tối đa 5MB',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onPick,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: const Text('Chọn tệp', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelected(BuildContext context) {
    final path = imagePath!;
    final name = kycImageDisplayName(path);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              InkWell(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tải lên thành công',
          style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
