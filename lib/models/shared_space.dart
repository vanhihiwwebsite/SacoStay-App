class SharedSpaceShortlistItem {
  const SharedSpaceShortlistItem({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.price,
    required this.address,
    required this.isAddedByMe,
    required this.myVote,
    required this.partnerVote,
    this.roomCategory,
  });

  final String id;
  final String roomId;
  final String roomTitle;
  final String? roomCategory;
  final int price;
  final String address;
  final bool isAddedByMe;
  final String myVote;
  final String partnerVote;
}

class SharedSpaceCurrent {
  const SharedSpaceCurrent({
    required this.id,
    required this.myId,
    required this.myName,
    required this.partnerId,
    required this.partnerName,
    required this.status,
    required this.shortlist,
    this.createdAt,
    this.finalizedRoomId,
    this.finalizeRequestedByUserId,
  });

  final String id;
  final String myId;
  final String myName;
  final String partnerId;
  final String partnerName;
  final String status;
  final String? createdAt;
  final String? finalizedRoomId;
  final String? finalizeRequestedByUserId;
  final List<SharedSpaceShortlistItem> shortlist;
}

class SharedSpaceSummary {
  const SharedSpaceSummary({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.status,
    required this.shortlistRoomIds,
    this.createdAt,
    this.finalizedRoomId,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String status;
  final String? createdAt;
  final String? finalizedRoomId;
  final List<String> shortlistRoomIds;
}
