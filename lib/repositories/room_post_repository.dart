import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/geo.dart';
import '../core/utils/json_normalize.dart';
import '../core/utils/media_url.dart';
import '../core/utils/vip_tier.dart';
import '../features/auth/auth_provider.dart';
import '../models/room_post.dart';

final roomPostRepositoryProvider = Provider<RoomPostRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RoomPostRepository(apiClient.dio);
});

class RoomPostRepository {
  RoomPostRepository(this._dio);

  final Dio _dio;

  Future<List<RoomPostSummary>> searchNearby({
    double userLat = 10.7769,
    double userLng = 106.7009,
    double radiusInKm = 25,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/RoomPost/search-nearby',
        queryParameters: {
          'userLat': userLat,
          'userLng': userLng,
          'radiusInKm': radiusInKm,
        },
      );
      return _normalizePosts(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<RoomPostSummary>> listForBrowse() async {
    final hn = await searchNearby(
      userLat: 21.0285,
      userLng: 105.8542,
      radiusInKm: 150,
    );
    final hcm = await searchNearby(
      userLat: 10.7769,
      userLng: 106.7009,
      radiusInKm: 150,
    );
    return _dedupeById([...hn, ...hcm]);
  }

  Future<RoomPostDetail?> getById(String id) async {
    try {
      final browseHn = await _fetchRawNearby(21.0285, 105.8542, 80);
      final browseHcm = await _fetchRawNearby(10.7769, 106.7009, 80);
      final mineRaw = await _fetchMyPostsRaw();
      final allRaw = [...mineRaw, ...browseHn, ...browseHcm];
      final rawHit = allRaw.firstWhere(
        (o) =>
            strField(
              pickField(o, 'id', ['Id', 'roomPostId', 'RoomPostId']),
            ) ==
            id,
        orElse: () => <String, dynamic>{},
      );
      if (rawHit.isEmpty) return null;

      var detail = _normalizeDetail(rawHit);
      if (detail == null) return null;

      final lat = detail.latitude;
      final lng = detail.longitude;
      if (lat != null && lng != null) {
        final labels = await _getNearbyHighlightLabels(lat, lng, id);
        if (labels.isNotEmpty) {
          detail = RoomPostDetail(
            id: detail.id,
            landlordUserId: detail.landlordUserId,
            title: detail.title,
            price: detail.price,
            address: detail.address,
            city: detail.city,
            district: detail.district,
            area: detail.area,
            maxPeople: detail.maxPeople,
            currentPeople: detail.currentPeople,
            imageUrl: detail.imageUrl,
            status: detail.status,
            viewCount: detail.viewCount,
            vipTier: detail.vipTier,
            amenities: detail.amenities,
            description: detail.description,
            latitude: detail.latitude,
            longitude: detail.longitude,
            images: detail.images,
            nearbyLandmarks: labels,
            landlordPhone: detail.landlordPhone,
            occupants: detail.occupants,
          );
        }
      }
      return detail;
    } catch (_) {
      return null;
    }
  }

  Future<void> recordView(String postId) async {
    try {
      await _dio.post('/RoomPost/${Uri.encodeComponent(postId)}/view');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchRawNearby(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/RoomPost/search-nearby',
        queryParameters: {
          'userLat': lat,
          'userLng': lng,
          'radiusInKm': radiusKm,
        },
      );
      return _unwrapList(response.data)
          .map((item) => _flattenRoomItem(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMyPostsRaw() async {
    try {
      final response = await _dio.get<dynamic>('/RoomPost/my-posts');
      return _unwrapList(response.data)
          .map((item) => _flattenRoomItem(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _getNearbyHighlightLabels(
    double lat,
    double lng,
    String excludePostId,
  ) async {
    final rooms = await searchNearby(
      userLat: lat,
      userLng: lng,
      radiusInKm: 2.5,
    );
    final labels = <String>[];
    final seen = <String>{};

    for (final room in rooms) {
      if (room.id == excludePostId) continue;
      if (!room.hasCoordinates) continue;
      final km = haversineKm(lat, lng, room.latitude!, room.longitude!);
      if (km < 0.08) continue;

      final label = _landmarkLabelFromRoom(room, km);
      final key = label.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      labels.add(label);
      if (labels.length >= 3) break;
    }
    return labels;
  }

  String _landmarkLabelFromRoom(RoomPostSummary room, double distanceKm) {
    final meters = distanceKm < 1
        ? '${(distanceKm * 1000).round()}m'
        : '${distanceKm.toStringAsFixed(1)}km';
    final addr = (room.address ?? '').split(',').first.trim();
    if (addr.length > 3 && addr.length < 60) {
      return '$addr (cách ~$meters)';
    }
    return '${room.title} (cách ~$meters)';
  }

  Map<String, dynamic> _flattenRoomItem(dynamic item) {
    if (item is! Map) return {};
    final o = Map<String, dynamic>.from(item);
    final nested = pickField(o, 'room', ['Room']);
    if (nested is Map) {
      return {...Map<String, dynamic>.from(nested), ...o};
    }
    return o;
  }

  RoomPostDetail? _normalizeDetail(Map<String, dynamic> o) {
    final base = _normalizeSummary(o, 0);
    if (base == null) return null;

    final description = strField(pickField(o, 'description', ['Description']));
    final images = _extractImages(o);
    final amenities = _extractAmenities(o);
    final nearbyRaw = pickField(
      o,
      'nearbyLandmarks',
      ['NearbyLandmarks', 'landmarks', 'Landmarks'],
    );
    final nearbyLandmarks = nearbyRaw is List
        ? nearbyRaw.map((x) => strField(x)).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final landlordPhone = strField(
      pickField(
        o,
        'landlordPhone',
        [
          'LandlordPhone',
          'phoneNumber',
          'PhoneNumber',
          'contactPhone',
          'ContactPhone',
        ],
      ),
    );
    final landlordUserId = strField(
      pickField(
        o,
        'landlordUserId',
        ['LandlordUserId', 'userId', 'UserId', 'ownerId', 'OwnerId'],
      ),
    );
    final occupants = _normalizeOccupants(o);

    return RoomPostDetail(
      id: base.id,
      landlordUserId:
          landlordUserId.isNotEmpty ? landlordUserId : base.landlordUserId,
      title: base.title,
      price: base.price,
      address: base.address,
      city: base.city,
      district: base.district,
      area: base.area,
      maxPeople: base.maxPeople,
      currentPeople: base.currentPeople,
      imageUrl: base.imageUrl,
      status: base.status,
      viewCount: base.viewCount,
      vipTier: base.vipTier,
      amenities: amenities.isNotEmpty ? amenities : base.amenities,
      description: description.isNotEmpty ? description : base.description,
      latitude: base.latitude,
      longitude: base.longitude,
      images: images.isNotEmpty
          ? images
          : (base.imageUrl != null ? [base.imageUrl!] : []),
      nearbyLandmarks: nearbyLandmarks,
      landlordPhone: landlordPhone.isNotEmpty ? landlordPhone : null,
      occupants: occupants,
    );
  }

  List<RoomOccupant> _normalizeOccupants(Map<String, dynamic> o) {
    final raw = pickField(
      o,
      'occupants',
      ['Occupants', 'roommates', 'Roommates', 'currentOccupants', 'CurrentOccupants'],
    );
    if (raw is! List) return [];
    final result = <RoomOccupant>[];
    for (final item in raw) {
      if (item is String || item is num) {
        final id = strField(item);
        if (id.isNotEmpty) {
          result.add(RoomOccupant(id: id, name: 'Thành viên'));
        }
        continue;
      }
      if (item is! Map) continue;
      final u = Map<String, dynamic>.from(item);
      final id = strField(
        pickField(u, 'id', ['Id', 'userId', 'UserId']),
      );
      if (id.isEmpty) continue;
      final name = strField(
        pickField(u, 'name', ['Name', 'userName', 'UserName']),
      );
      final avatar = strField(pickField(u, 'avatar', ['Avatar']));
      final age = num.tryParse(
        strField(pickField(u, 'age', ['Age'])),
      )?.round();
      final occupation = strField(
        pickField(u, 'job', ['Job', 'occupation', 'Occupation']),
      );
      result.add(
        RoomOccupant(
          id: id,
          name: name.isNotEmpty ? name : 'Thành viên',
          avatar: avatar.isNotEmpty ? resolveMediaUrl(avatar) : null,
          age: age,
          occupation: occupation.isNotEmpty ? occupation : null,
        ),
      );
    }
    return result;
  }

  List<RoomPostSummary> _dedupeById(List<RoomPostSummary> rooms) {
    final seen = <String>{};
    return rooms.where((r) {
      if (seen.contains(r.id)) return false;
      seen.add(r.id);
      return true;
    }).toList();
  }

  List<RoomPostSummary> _normalizePosts(dynamic raw) {
    final items = _unwrapList(raw);
    final result = <RoomPostSummary>[];
    for (var i = 0; i < items.length; i++) {
      final room = _normalizeSummary(items[i], i);
      if (room != null) result.add(room);
    }
    return result;
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw as Map);
    final nested = pickField(
      map,
      'data',
      ['items', 'result', 'posts', 'roomPosts', 'RoomPosts', 'value', r'$values'],
    );
    if (nested is List) return nested;
    return [];
  }

  RoomPostSummary? _normalizeSummary(dynamic item, int index) {
    if (item is! Map) return null;
    final o = Map<String, dynamic>.from(item as Map);
    final id = strField(
      pickField(o, 'id', ['Id', 'roomPostId', 'RoomPostId']),
    );
    final title = strField(
      pickField(o, 'title', ['Title', 'name', 'Name']),
    );
    final priceNum = num.tryParse(
      strField(pickField(o, 'price', ['Price'])),
    ) ??
        (pickField(o, 'price', ['Price']) as num? ?? 0);
    final images = _extractImages(o);
    final imageUrl = images.isNotEmpty
        ? images.first
        : strField(
            pickField(
              o,
              'imageUrl',
              ['ImageUrl', 'thumbnail', 'Thumbnail'],
            ),
          );
    final areaNum = num.tryParse(
      strField(pickField(o, 'area', ['Area'])),
    ) ??
        (pickField(o, 'area', ['Area']) as num? ?? 0);
    final maxNum = num.tryParse(
      strField(
        pickField(
          o,
          'maxPeople',
          ['MaxPeople', 'maxOccupants', 'MaxOccupants'],
        ),
      ),
    ) ??
        (pickField(
              o,
              'maxPeople',
              ['MaxPeople', 'maxOccupants', 'MaxOccupants'],
            ) as num? ??
            0);
    final currentNum = num.tryParse(
      strField(
        pickField(
          o,
          'currentPeople',
          ['CurrentPeople', 'currentOccupants', 'CurrentOccupants'],
        ),
      ),
    );
    int? currentPeople;
    if (currentNum != null && currentNum >= 0) {
      currentPeople = currentNum.round();
    } else if (maxNum > 0) {
      currentPeople = 0;
    }
    final occupants = pickField(
      o,
      'currentOccupants',
      ['CurrentOccupants'],
    );
    if (currentPeople == null && occupants is List) {
      currentPeople = occupants.length;
    }
    final landlordUserId = strField(
      pickField(
        o,
        'landlordUserId',
        ['LandlordUserId', 'userId', 'UserId', 'ownerId', 'OwnerId'],
      ),
    );
    final city = strField(pickField(o, 'city', ['City']));
    final district = strField(pickField(o, 'district', ['District']));
    final addressStr = strField(
      pickField(
        o,
        'detailedAddress',
        ['DetailedAddress', 'address', 'Address'],
      ),
    );
    final fullAddress = [addressStr, district, city]
        .where((s) => s.isNotEmpty)
        .join(', ');
    final coords = _extractCoordinates(o);
    final resolvedImage =
        imageUrl.isNotEmpty ? resolveMediaUrl(imageUrl) : null;

    return RoomPostSummary(
      id: id.isNotEmpty ? id : 'post-$index',
      landlordUserId: landlordUserId.isNotEmpty ? landlordUserId : null,
      title: title.isNotEmpty ? title : 'Tin #${index + 1}',
      price: priceNum > 0 ? priceNum.round() : null,
      address: fullAddress.isNotEmpty ? fullAddress : (addressStr.isNotEmpty ? addressStr : null),
      city: city.isNotEmpty ? city : null,
      district: district.isNotEmpty ? district : null,
      area: areaNum > 0 ? areaNum.toDouble() : null,
      maxPeople: maxNum > 0 ? maxNum.round() : null,
      currentPeople: currentPeople,
      imageUrl: resolvedImage,
      status: strField(pickField(o, 'status', ['Status'])).isNotEmpty
          ? strField(pickField(o, 'status', ['Status']))
          : null,
      viewCount: num.tryParse(
            strField(pickField(o, 'viewCount', ['ViewCount'])),
          )?.round() ??
          0,
      vipTier: parseRoomVipTier(
        pickField(
          o,
          'packageTier',
          ['PackageTier', 'vipTier', 'VipTier', 'vipLevel', 'VipLevel'],
        ),
      ),
      amenities: _extractAmenities(o),
      description: strField(pickField(o, 'description', ['Description'])).isNotEmpty
          ? strField(pickField(o, 'description', ['Description']))
          : null,
      latitude: coords.lat,
      longitude: coords.lng,
    );
  }

  ({double? lat, double? lng}) _extractCoordinates(Map<String, dynamic> o) {
    final loc = pickField(o, 'location', ['Location']);
    if (loc is Map) {
      final l = Map<String, dynamic>.from(loc);
      final lat = num.tryParse(
        strField(
          pickField(l, 'latitude', ['Latitude', 'lat', 'Lat']),
        ),
      ) ??
          (pickField(l, 'latitude', ['Latitude', 'lat', 'Lat']) as num?);
      final lng = num.tryParse(
        strField(
          pickField(l, 'longitude', ['Longitude', 'lng', 'Lng']),
        ),
      ) ??
          (pickField(l, 'longitude', ['Longitude', 'lng', 'Lng']) as num?);
      if (lat != null && lng != null) {
        return (lat: lat.toDouble(), lng: lng.toDouble());
      }
    }
    final lat = num.tryParse(
      strField(pickField(o, 'latitude', ['Latitude', 'lat', 'Lat'])),
    ) ??
        (pickField(o, 'latitude', ['Latitude', 'lat', 'Lat']) as num?);
    final lng = num.tryParse(
      strField(pickField(o, 'longitude', ['Longitude', 'lng', 'Lng'])),
    ) ??
        (pickField(o, 'longitude', ['Longitude', 'lng', 'Lng']) as num?);
    if (lat != null && lng != null) {
      return (lat: lat.toDouble(), lng: lng.toDouble());
    }
    return (lat: null, lng: null);
  }

  List<String> _extractImages(Map<String, dynamic> o) {
    final images = pickField(
      o,
      'images',
      ['Images', 'imageUrls', 'ImageUrls', 'imageFiles', 'ImageFiles'],
    );
    if (images is! List) return [];
    return images
        .map((x) => resolveMediaUrl(strField(x)))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _extractAmenities(Map<String, dynamic> o) {
    final raw = pickField(o, 'amenities', ['Amenities']);
    if (raw is! List) return [];
    return raw.map((x) => strField(x)).where((s) => s.isNotEmpty).toList();
  }
}
