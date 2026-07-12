import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../features/auth/auth_provider.dart';
import '../models/shared_space.dart';

final sharedSpaceRepositoryProvider = Provider<SharedSpaceRepository>((ref) {
  return SharedSpaceRepository(ref.watch(apiClientProvider).dio);
});

class SharedSpaceRepository {
  SharedSpaceRepository(this._dio);

  final Dio _dio;

  Future<({String spaceId, String message})> createSpace(String targetUserId) async {
    final response = await _dio.post<dynamic>(
      '/SharedSpace/create',
      data: {'targetUserId': targetUserId},
    );
    final raw = response.data;
    return (
      spaceId: strField(pickField(raw, 'spaceId', ['SpaceId'])),
      message: _messageFromResponse(
        raw: raw,
        fallback: 'Khởi tạo không gian chung thành công.',
      ),
    );
  }

  Future<SharedSpaceCurrent?> getCurrentSpace() async {
    try {
      final response = await _dio.get<dynamic>('/SharedSpace/current');
      return _normalizeCurrent(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<SharedSpaceSummary>> listSpaces() async {
    try {
      final response = await _dio.get<dynamic>('/SharedSpace/list');
      final raw = response.data;
      if (raw is! List) return [];
      return raw
          .map(_normalizeSummary)
          .whereType<SharedSpaceSummary>()
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<SharedSpaceCurrent?> getSpaceById(String spaceId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/SharedSpace/${Uri.encodeComponent(spaceId)}',
      );
      return _normalizeCurrent(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> addToShortlist(String spaceId, String roomId) async {
    final response = await _dio.post<dynamic>(
      '/SharedSpace/${Uri.encodeComponent(spaceId)}/shortlist',
      data: {'roomId': roomId},
    );
    return _messageFromResponse(raw: response.data, fallback: 'Đã thêm phòng vào danh sách chung.');
  }

  Future<String> voteRoom(String shortlistId, String voteStatus) async {
    final response = await _dio.post<dynamic>(
      '/SharedSpace/shortlist/${Uri.encodeComponent(shortlistId)}/vote',
      data: {'voteStatus': voteStatus},
    );
    return _messageFromResponse(raw: response.data, fallback: 'Đã cập nhật biểu quyết.');
  }

  Future<String> proposeFinalize(String spaceId, String shortlistId) async {
    final response = await _dio.put<dynamic>(
      '/SharedSpace/${Uri.encodeComponent(spaceId)}/propose-finalize',
      data: {'shortlistId': shortlistId},
    );
    return _messageFromResponse(raw: response.data, fallback: 'Đã gửi đề xuất chốt phòng.');
  }

  Future<String> acceptFinalize(String spaceId) async {
    final response = await _dio.put<dynamic>(
      '/SharedSpace/${Uri.encodeComponent(spaceId)}/accept-finalize',
      data: <String, dynamic>{},
    );
    return _messageFromResponse(raw: response.data, fallback: 'Đã chốt phòng thành công!');
  }

  Future<String> rejectFinalize(String spaceId) async {
    final response = await _dio.put<dynamic>(
      '/SharedSpace/${Uri.encodeComponent(spaceId)}/reject-finalize',
      data: <String, dynamic>{},
    );
    return _messageFromResponse(raw: response.data, fallback: 'Đã hủy đề xuất chốt phòng.');
  }

  String _messageFromResponse({required dynamic raw, required String fallback}) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is Map) {
      final o = Map<String, dynamic>.from(raw);
      final msg = pickField(o, 'message', ['Message']);
      final s = strField(msg);
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  SharedSpaceSummary? _normalizeSummary(dynamic raw) {
    if (raw is! Map) return null;
    final o = Map<String, dynamic>.from(raw);
    final id = strField(pickField(o, 'id', ['Id']));
    if (id.isEmpty) return null;

    final roomIdsRaw = pickField(o, 'shortlistRoomIds', ['ShortlistRoomIds']);
    final shortlistRoomIds = roomIdsRaw is List
        ? roomIdsRaw.map((v) => strField(v)).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final finalized = strField(pickField(o, 'finalizedRoomId', ['FinalizedRoomId']));

    return SharedSpaceSummary(
      id: id,
      partnerId: strField(pickField(o, 'partnerId', ['PartnerId'])),
      partnerName: strField(pickField(o, 'partnerName', ['PartnerName'])).isEmpty
          ? 'Bạn cùng phòng'
          : strField(pickField(o, 'partnerName', ['PartnerName'])),
      status: strField(pickField(o, 'status', ['Status'])).isEmpty
          ? 'Active'
          : strField(pickField(o, 'status', ['Status'])),
      createdAt: strField(pickField(o, 'createdAt', ['CreatedAt'])).isEmpty
          ? null
          : strField(pickField(o, 'createdAt', ['CreatedAt'])),
      finalizedRoomId: finalized.isEmpty ? null : finalized,
      shortlistRoomIds: shortlistRoomIds,
    );
  }

  SharedSpaceCurrent? _normalizeCurrent(dynamic raw) {
    if (raw is! Map) return null;
    final o = Map<String, dynamic>.from(raw);
    final id = strField(pickField(o, 'id', ['Id']));
    if (id.isEmpty) return null;

    final shortlistRaw = pickField(o, 'shortlist', ['Shortlist']);
    final shortlist = shortlistRaw is List
        ? shortlistRaw
            .map(_normalizeShortlistItem)
            .whereType<SharedSpaceShortlistItem>()
            .toList()
        : <SharedSpaceShortlistItem>[];

    final finalized = strField(pickField(o, 'finalizedRoomId', ['FinalizedRoomId']));
    final finalizeBy = strField(
      pickField(o, 'finalizeRequestedByUserId', ['FinalizeRequestedByUserId']),
    );

    return SharedSpaceCurrent(
      id: id,
      myId: strField(pickField(o, 'myId', ['MyId'])),
      myName: strField(pickField(o, 'myName', ['MyName'])).isEmpty
          ? 'Tôi'
          : strField(pickField(o, 'myName', ['MyName'])),
      partnerId: strField(pickField(o, 'partnerId', ['PartnerId'])),
      partnerName: strField(pickField(o, 'partnerName', ['PartnerName'])).isEmpty
          ? 'Bạn cùng phòng'
          : strField(pickField(o, 'partnerName', ['PartnerName'])),
      status: strField(pickField(o, 'status', ['Status'])).isEmpty
          ? 'Active'
          : strField(pickField(o, 'status', ['Status'])),
      createdAt: strField(pickField(o, 'createdAt', ['CreatedAt'])).isEmpty
          ? null
          : strField(pickField(o, 'createdAt', ['CreatedAt'])),
      finalizedRoomId: finalized.isEmpty ? null : finalized,
      finalizeRequestedByUserId: finalizeBy.isEmpty ? null : finalizeBy,
      shortlist: shortlist,
    );
  }

  SharedSpaceShortlistItem? _normalizeShortlistItem(dynamic raw) {
    if (raw is! Map) return null;
    final o = Map<String, dynamic>.from(raw);
    final id = strField(pickField(o, 'id', ['Id']));
    final roomId = strField(pickField(o, 'roomId', ['RoomId']));
    if (id.isEmpty || roomId.isEmpty) return null;

    final priceRaw = pickField(o, 'price', ['Price']);
    final price = num.tryParse(strField(priceRaw))?.round() ?? 0;
    final category = strField(pickField(o, 'roomCategory', ['RoomCategory']));

    return SharedSpaceShortlistItem(
      id: id,
      roomId: roomId,
      roomTitle: strField(pickField(o, 'roomTitle', ['RoomTitle'])).isEmpty
          ? 'Phòng trọ'
          : strField(pickField(o, 'roomTitle', ['RoomTitle'])),
      roomCategory: category.isEmpty ? null : category,
      price: price,
      address: strField(pickField(o, 'address', ['Address'])),
      isAddedByMe: pickField(o, 'isAddedByMe', ['IsAddedByMe']) == true,
      myVote: strField(pickField(o, 'myVote', ['MyVote'])).isEmpty
          ? 'None'
          : strField(pickField(o, 'myVote', ['MyVote'])),
      partnerVote: strField(pickField(o, 'partnerVote', ['PartnerVote'])).isEmpty
          ? 'None'
          : strField(pickField(o, 'partnerVote', ['PartnerVote'])),
    );
  }
}
