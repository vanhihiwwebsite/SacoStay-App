class AdminDashboardStats {
  const AdminDashboardStats({
    this.totalUsers = 0,
    this.totalListings = 0,
    this.pendingListings = 0,
    this.openReports = 0,
  });

  final int totalUsers;
  final int totalListings;
  final int pendingListings;
  final int openReports;
}

class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.displayName,
    this.email,
    this.roles = const [],
    this.isVerified = false,
  });

  final String id;
  final String displayName;
  final String? email;
  final List<String> roles;
  final bool isVerified;
}

class AdminListingRow {
  const AdminListingRow({
    required this.id,
    required this.title,
    this.landlordName,
    this.status,
    this.city,
    this.price,
  });

  final String id;
  final String title;
  final String? landlordName;
  final String? status;
  final String? city;
  final int? price;
}

class AdminReportRow {
  const AdminReportRow({
    required this.id,
    required this.reason,
    this.reporterName,
    this.targetLabel,
    this.status,
    this.createdAt,
  });

  final String id;
  final String reason;
  final String? reporterName;
  final String? targetLabel;
  final String? status;
  final DateTime? createdAt;
}
