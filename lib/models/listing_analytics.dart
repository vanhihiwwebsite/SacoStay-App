/// GET /api/RoomPost/{id}/analytics — mirror web `RoomPostViewAnalytics`.
class ListingViewerRow {
  const ListingViewerRow({
    required this.tenantId,
    required this.viewedAt,
    required this.roomPostId,
    required this.roomTitle,
  });

  final String tenantId;
  final String viewedAt;
  final String roomPostId;
  final String roomTitle;
}

class RoomPostViewAnalytics {
  const RoomPostViewAnalytics({
    required this.postId,
    this.roomTitle = '',
    this.currentPackage = 'BASIC',
    this.isLimitedView = true,
    this.totalViewsIn24H = 0,
    this.viewers = const [],
  });

  final String postId;
  final String roomTitle;
  final String currentPackage;
  final bool isLimitedView;
  final int totalViewsIn24H;
  final List<ListingViewerRow> viewers;
}
