import 'package:flutter/material.dart' show Color, FontWeight, TextStyle;

import '../../models/room_post.dart';

enum VipTier { free, vip1, vip2, vip3 }

const _vipRank = {
  VipTier.vip3: 0,
  VipTier.vip2: 1,
  VipTier.vip1: 2,
  VipTier.free: 3,
};

String normalizeLandlordPackageCode(dynamic raw) {
  final s =
      (raw ?? '').toString().trim().toLowerCase().replaceFirst(RegExp(r'^landlord_'), '');
  if (s == 'elite' || s == 'vip3' || s == '3') return 'ELITE';
  if (s == 'pro' || s == 'vip2' || s == '2') return 'PRO';
  if (s == 'lite' || s == 'vip1' || s == '1') return 'LITE';
  return 'BASIC';
}

VipTier parseRoomVipTier(dynamic raw) {
  final code = normalizeLandlordPackageCode(raw);
  if (code == 'ELITE') return VipTier.vip3;
  if (code == 'PRO') return VipTier.vip2;
  if (code == 'LITE') return VipTier.vip1;
  return VipTier.free;
}

VipTier resolveVipTier(VipTier? tier) => tier ?? VipTier.free;

List<RoomPostSummary> sortRoomsByVipTier(List<RoomPostSummary> rooms) {
  final copy = List<RoomPostSummary>.from(rooms);
  copy.sort((a, b) {
    final ra = _vipRank[a.vipTier] ?? 3;
    final rb = _vipRank[b.vipTier] ?? 3;
    if (ra != rb) return ra.compareTo(rb);
    return (b.price ?? 0).compareTo(a.price ?? 0);
  });
  return copy;
}

Color vipTierMarkerColor(VipTier tier, {bool selected = false}) {
  if (selected) return const Color(0xFFFF6B6B);
  switch (tier) {
    case VipTier.vip3:
      return const Color(0xFFEF4444);
    case VipTier.vip2:
      return const Color(0xFFF59E0B);
    case VipTier.vip1:
      return const Color(0xFF2563EB);
    case VipTier.free:
      return const Color(0xFF9CA3AF);
  }
}

Color vipTierPriceBadgeColor(VipTier tier) {
  switch (tier) {
    case VipTier.vip3:
      return const Color(0xFFEF4444);
    case VipTier.vip2:
      return const Color(0xFFF59E0B);
    case VipTier.vip1:
      return const Color(0xFF2563EB);
    case VipTier.free:
      return const Color(0xFFFF9F43);
  }
}

Color vipTierTitleColor(VipTier tier) {
  switch (tier) {
    case VipTier.vip3:
      return const Color(0xFFEF4444);
    case VipTier.vip2:
      return const Color(0xFFF59E0B);
    case VipTier.vip1:
      return const Color(0xFF2563EB);
    case VipTier.free:
      return const Color(0xFF374151);
  }
}

TextStyle vipTierTitleStyle(VipTier tier, {bool compact = false}) {
  final color = vipTierTitleColor(tier);
  if (compact) {
    switch (tier) {
      case VipTier.vip3:
        return TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900);
      case VipTier.vip2:
        return TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800);
      case VipTier.vip1:
        return TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700);
      case VipTier.free:
        return TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500);
    }
  }
  switch (tier) {
    case VipTier.vip3:
      return TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900);
    case VipTier.vip2:
      return TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800);
    case VipTier.vip1:
      return TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700);
    case VipTier.free:
      return TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500);
  }
}
