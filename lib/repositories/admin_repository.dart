import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json_normalize.dart';
import '../features/auth/auth_provider.dart';
import '../models/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider).dio);
});

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<AdminDashboardStats> getDashboard() async {
    try {
      final response = await _dio.get<dynamic>('/Admin/dashboard');
      return _normalizeDashboard(response.data);
    } catch (_) {
      return const AdminDashboardStats();
    }
  }

  Future<List<AdminUserRow>> getUsers({int limit = 50}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Admin/users',
        queryParameters: {'limit': limit},
      );
      return _normalizeUsers(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<AdminListingRow>> getRoomPosts({String? status}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Admin/room-posts',
        queryParameters: status != null && status.isNotEmpty
            ? {'status': status}
            : null,
      );
      return _normalizeListings(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> approveListing(String id) async {
    await _dio.post('/Admin/room-posts/${Uri.encodeComponent(id)}/approve');
  }

  Future<void> rejectListing(String id) async {
    await _dio.post('/Admin/room-posts/${Uri.encodeComponent(id)}/reject');
  }

  Future<List<AdminReportRow>> getReports() async {
    try {
      final response = await _dio.get<dynamic>('/Report');
      return _normalizeReports(response.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> processReport({
    required String id,
    required bool isValid,
    String? adminNote,
  }) async {
    await _dio.post(
      '/Admin/reports/${Uri.encodeComponent(id)}/process',
      data: {
        'isValid': isValid,
        'IsValid': isValid,
        if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
        if (adminNote != null && adminNote.isNotEmpty) 'AdminNote': adminNote,
      },
    );
  }

  AdminDashboardStats _normalizeDashboard(dynamic raw) {
    final o = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final nested = o['data'] is Map ? Map<String, dynamic>.from(o['data'] as Map) : o;
    int pick(String camel, List<String> keys) {
      return num.tryParse(
            strField(pickField(nested, camel, keys)),
          )?.round() ??
          (pickField(nested, camel, keys) as num?)?.round() ??
          0;
    }

    return AdminDashboardStats(
      totalUsers: pick('totalUsers', ['TotalUsers', 'users', 'Users']),
      totalListings: pick('totalListings', ['TotalListings', 'listings', 'Listings']),
      pendingListings: pick('pendingListings', ['PendingListings', 'pending', 'Pending']),
      openReports: pick('openReports', ['OpenReports', 'reports', 'Reports']),
    );
  }

  List<AdminUserRow> _normalizeUsers(dynamic raw) {
    return _unwrapList(raw).map((item) {
      if (item is! Map) return null;
      final o = Map<String, dynamic>.from(item);
      final id = strField(pickField(o, 'id', ['Id', 'userId', 'UserId']));
      if (id.isEmpty) return null;
      final fn = strField(pickField(o, 'firstName', ['FirstName']));
      final ln = strField(pickField(o, 'lastName', ['LastName']));
      final name = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
      return AdminUserRow(
        id: id,
        displayName: name.isNotEmpty
            ? name
            : strField(pickField(o, 'userName', ['UserName', 'email', 'Email'])),
        email: strField(pickField(o, 'email', ['Email'])).isNotEmpty
            ? strField(pickField(o, 'email', ['Email']))
            : null,
        roles: listOfStrings(o['roles'] ?? o['Roles']),
        isVerified: pickField(o, 'isVerified', ['IsVerified']) == true,
      );
    }).whereType<AdminUserRow>().toList();
  }

  List<AdminListingRow> _normalizeListings(dynamic raw) {
    return _unwrapList(raw).map((item) {
      if (item is! Map) return null;
      final o = Map<String, dynamic>.from(item);
      final id = strField(pickField(o, 'id', ['Id', 'roomPostId', 'RoomPostId']));
      if (id.isEmpty) return null;
      return AdminListingRow(
        id: id,
        title: strField(pickField(o, 'title', ['Title'])) ,
        landlordName: strField(
          pickField(o, 'landlordName', ['LandlordName', 'ownerName', 'OwnerName']),
        ).isNotEmpty
            ? strField(pickField(o, 'landlordName', ['LandlordName', 'ownerName', 'OwnerName']))
            : null,
        status: strField(pickField(o, 'status', ['Status'])).isNotEmpty
            ? strField(pickField(o, 'status', ['Status']))
            : null,
        city: strField(pickField(o, 'city', ['City'])).isNotEmpty
            ? strField(pickField(o, 'city', ['City']))
            : null,
        price: num.tryParse(strField(pickField(o, 'price', ['Price'])))?.round(),
      );
    }).whereType<AdminListingRow>().toList();
  }

  List<AdminReportRow> _normalizeReports(dynamic raw) {
    return _unwrapList(raw).map((item) {
      if (item is! Map) return null;
      final o = Map<String, dynamic>.from(item);
      final id = strField(pickField(o, 'id', ['Id', 'reportId', 'ReportId']));
      if (id.isEmpty) return null;
      final createdRaw = strField(
        pickField(o, 'createdAt', ['CreatedAt', 'reportedAt', 'ReportedAt']),
      );
      return AdminReportRow(
        id: id,
        reason: strField(pickField(o, 'reason', ['Reason', 'description', 'Description'])),
        reporterName: strField(
          pickField(o, 'reporterName', ['ReporterName', 'reporter', 'Reporter']),
        ).isNotEmpty
            ? strField(pickField(o, 'reporterName', ['ReporterName']))
            : null,
        targetLabel: strField(
          pickField(o, 'targetLabel', ['TargetLabel', 'target', 'Target']),
        ).isNotEmpty
            ? strField(pickField(o, 'targetLabel', ['TargetLabel']))
            : null,
        status: strField(pickField(o, 'status', ['Status'])).isNotEmpty
            ? strField(pickField(o, 'status', ['Status']))
            : null,
        createdAt: createdRaw.isNotEmpty ? DateTime.tryParse(createdRaw) : null,
      );
    }).whereType<AdminReportRow>().toList();
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    final nested = pickField(
      map,
      'data',
      ['items', 'users', 'Users', 'roomPosts', 'RoomPosts', 'reports', 'Reports'],
    );
    if (nested is List) return nested;
    return [];
  }
}
