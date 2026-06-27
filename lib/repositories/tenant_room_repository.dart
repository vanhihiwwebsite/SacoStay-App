import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../core/utils/media_url.dart';
import '../features/auth/auth_provider.dart';
import '../models/tenant_room_profile.dart';

final tenantRoomRepositoryProvider = Provider<TenantRoomRepository>((ref) {
  return TenantRoomRepository(ref.watch(apiClientProvider).dio);
});

class TenantRoomRepository {
  TenantRoomRepository(this._dio);

  final Dio _dio;

  Future<TenantRoomProfile?> getByUserId(String userId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/TenantRoomProfile/user/${Uri.encodeComponent(userId)}',
      );
      return _normalize(response.data);
    } catch (_) {
      return null;
    }
  }

  TenantRoomProfile? _normalize(dynamic raw) {
    if (raw is! Map) return null;
    var o = Map<String, dynamic>.from(raw);
    final nested = o['data'] ?? o['Data'];
    if (nested is Map) o = Map<String, dynamic>.from(nested);

    final amenitiesRaw = pickField(o, 'amenities', ['Amenities']);
    final amenities = amenitiesRaw is List
        ? amenitiesRaw.map((e) => strField(e)).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final imagesRaw = pickField(o, 'images', ['Images']);
    final images = imagesRaw is List
        ? imagesRaw
            .map((e) => resolveMediaUrl(strField(e)))
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final price = num.tryParse(strField(pickField(o, 'price', ['Price'])));

    return TenantRoomProfile(
      userId: strField(pickField(o, 'userId', ['UserId'])),
      city: strField(pickField(o, 'city', ['City'])).isEmpty
          ? null
          : strField(pickField(o, 'city', ['City'])),
      district: strField(pickField(o, 'district', ['District'])).isEmpty
          ? null
          : strField(pickField(o, 'district', ['District'])),
      maxPeople: num.tryParse(
        strField(pickField(o, 'maxPeople', ['MaxPeople'])),
      )?.round(),
      price: price != null && price > 0 ? price.round() : null,
      amenities: amenities,
      extraNotes: strField(pickField(o, 'extraNotes', ['ExtraNotes'])).isEmpty
          ? null
          : strField(pickField(o, 'extraNotes', ['ExtraNotes'])),
      images: images,
    );
  }
}
