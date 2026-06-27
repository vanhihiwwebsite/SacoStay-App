import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room_post.dart';
import '../../repositories/room_post_repository.dart';

final roomPostsProvider = FutureProvider.autoDispose<List<RoomPostSummary>>((ref) {
  return ref.watch(roomPostRepositoryProvider).listForBrowse();
});

final roomDetailProvider =
    FutureProvider.autoDispose.family<RoomPostDetail?, String>((ref, id) {
  return ref.watch(roomPostRepositoryProvider).getById(id);
});
