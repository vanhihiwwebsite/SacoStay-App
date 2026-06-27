import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../core/utils/lifestyle_display.dart';
import '../../../models/tenant_room_profile.dart';

class TenantRoomDetailsView extends StatelessWidget {
  const TenantRoomDetailsView({
    super.key,
    required this.profile,
    this.priceLabel = '',
  });

  final TenantRoomProfile? profile;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    final displayPrice = tenantRoomPriceLabel(profile?.price) != ''
        ? tenantRoomPriceLabel(profile?.price)
        : priceLabel.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Địa điểm', tenantRoomLocationLabel(profile)),
        const SizedBox(height: 12),
        _section('Số người tối đa', tenantRoomMaxPeopleLabel(profile?.maxPeople)),
        if (displayPrice.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('Giá tiền trọ', displayPrice, highlight: true),
        ],
        const SizedBox(height: 12),
        Text(
          'TIỆN NGHI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        if (profile?.amenities.isEmpty ?? true)
          Text('Chưa ghi nhận tiện nghi', style: TextStyle(color: Colors.grey.shade600))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: profile!.amenities.map((a) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SacoColors.pageBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Text(a, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
          ),
        if (profile?.images.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(
            'ẢNH PHÒNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: profile!.images.length,
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(profile!.images[i], fit: BoxFit.cover),
            ),
          ),
        ],
        if (profile?.extraNotes != null && profile!.extraNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('Thông tin thêm', profile!.extraNotes!),
        ],
      ],
    );
  }

  Widget _section(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: highlight ? SacoColors.sacoOrange : Colors.black87,
          ),
        ),
      ],
    );
  }
}
