enum KycApiStatus {
  notSubmitted,
  pending,
  approved,
  rejected,
  needReupload,
}

class KycStatus {
  const KycStatus({
    required this.status,
    this.adminNote,
    this.submittedAt,
  });

  final KycApiStatus status;
  final String? adminNote;
  final String? submittedAt;

  bool get isApproved => status == KycApiStatus.approved;
  bool get isPending => status == KycApiStatus.pending;
}
