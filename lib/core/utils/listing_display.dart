import 'package:flutter/material.dart';

import '../../core/utils/vip_tier.dart';

String _listingStatusKey(String? status) =>
    (status ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

bool isListingActive(String? status) => _listingStatusKey(status) == 'active';

bool isListingPendingPayment(String? status) {
  final s = _listingStatusKey(status);
  return s == 'pendingpayment' || (s.contains('pending') && s.contains('payment'));
}

bool isListingPendingApproval(String? status) {
  final s = _listingStatusKey(status);
  return s == 'pendingapproval' || s == 'pending';
}

bool isListingHidden(String? status) => _listingStatusKey(status) == 'hidden';

String listingStatusLabel(String? status) {
  final s = _listingStatusKey(status);
  if (s == 'pendingpayment' || (s.contains('pending') && s.contains('payment'))) {
    return 'Chờ thanh toán';
  }
  if (s == 'pendingapproval' || s == 'pending') return 'Chờ duyệt';
  if (s == 'active' || s == 'available') return 'Đang hiển thị';
  if (s == 'rented') return 'Đã cho thuê';
  if (s == 'hidden') return 'Đã bị từ chối';
  if (s == 'inactive') return 'Tạm ẩn';
  if (s == 'rejected') return 'Từ chối';
  return status?.isNotEmpty == true ? status! : 'Không rõ';
}

Color listingStatusBg(String? status) {
  final s = (status ?? '').toLowerCase();
  if (s.contains('payment')) return const Color(0xFFFEF3C7);
  if (s == 'pending') return const Color(0xFFDBEAFE);
  if (s == 'active' || s == 'available') return const Color(0xFFD1FAE5);
  if (s == 'rejected') return const Color(0xFFFEE2E2);
  return Colors.grey.shade100;
}

Color listingStatusFg(String? status) {
  final s = (status ?? '').toLowerCase();
  if (s.contains('payment')) return const Color(0xFFB45309);
  if (s == 'pending') return const Color(0xFF1D4ED8);
  if (s == 'active' || s == 'available') return const Color(0xFF047857);
  if (s == 'rejected') return const Color(0xFFB91C1C);
  return Colors.grey.shade700;
}

String vipTierLabel(VipTier tier) {
  switch (tier) {
    case VipTier.vip3:
      return 'ELITE';
    case VipTier.vip2:
      return 'PRO';
    case VipTier.vip1:
      return 'LITE';
    case VipTier.free:
      return 'BASIC';
  }
}

Color vipTierBadgeColor(VipTier tier) {
  switch (tier) {
    case VipTier.vip3:
      return const Color(0xFFEF4444);
    case VipTier.vip2:
      return const Color(0xFFF59E0B);
    case VipTier.vip1:
      return const Color(0xFF2563EB);
    case VipTier.free:
      return Colors.grey.shade500;
  }
}

Widget vipTierBadge(VipTier tier) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: vipTierBadgeColor(tier),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      vipTierLabel(tier),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Widget listingStatusChip(String? status) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: listingStatusBg(status),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      listingStatusLabel(status),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: listingStatusFg(status),
      ),
    ),
  );
}
