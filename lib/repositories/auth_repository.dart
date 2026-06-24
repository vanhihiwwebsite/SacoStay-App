import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../core/storage/user_prefs.dart';
import '../core/utils/json_normalize.dart';
import '../models/user_profile.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    required UserPrefs userPrefs,
  })  : _dio = apiClient.dio,
        _tokenStorage = tokenStorage,
        _userPrefs = userPrefs;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final UserPrefs _userPrefs;

  Future<String?> getToken() => _tokenStorage.read();

  Future<UserProfile?> getCachedUser() async {
    final json = _userPrefs.cachedUserJson;
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistUser(UserProfile? user) async {
    if (user == null) {
      await _userPrefs.clearCachedUser();
      return;
    }
    await _userPrefs.setCachedUserJson(jsonEncode(user.raw));
  }

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/Auth/login',
        data: request.toJson(),
      );
      final loginResponse = LoginResponse.fromJson(
        Map<String, dynamic>.from(response.data ?? {}),
      );
      if (loginResponse.token.isEmpty) {
        throw ApiException(message: 'Đăng nhập thất bại — không nhận được token.');
      }
      await _tokenStorage.write(loginResponse.token);
      if (loginResponse.user != null) {
        await _persistUser(loginResponse.user);
      }
      return loginResponse;
    } on DioException catch (e) {
      final apiMsg = _extractErrorMessage(e);
      final parsed = loginErrorFromApi(
        statusCode: e.response?.statusCode,
        apiMessage: apiMsg,
        networkMessage: e.message,
      );
      throw ApiException(
        message: parsed.message,
        statusCode: e.response?.statusCode,
        isBanned: parsed.isBanned,
      );
    }
  }

  Future<void> register(RegisterRequest request) async {
    try {
      await _dio.post('/Auth/register', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException(
        message: _extractErrorMessage(e) ?? 'Đăng ký thất bại. Thử lại sau.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      await _dio.post(
        '/Auth/verify-email-otp',
        queryParameters: {'email': email, 'otp': otp},
      );
    } on DioException catch (e) {
      throw ApiException(
        message: 'Mã OTP không đúng hoặc đã hết hạn. Vui lòng thử lại.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<UserProfile> getProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/Auth/profile');
      final user = UserProfile.fromJson(
        Map<String, dynamic>.from(response.data ?? {}),
      );
      await _persistUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException(
        message: _extractErrorMessage(e) ?? 'Không tải được hồ sơ.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<UserProfile?> refreshProfile() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;
    try {
      return await getProfile();
    } catch (_) {
      return await getCachedUser();
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final fd = FormData();
    void append(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        fd.fields.add(MapEntry(key, value.trim()));
      }
    }
    append('FirstName', firstName);
    append('LastName', lastName);
    append('PhoneNumber', phoneNumber);

    try {
      await _dio.put('/Auth/update-profile', data: fd);
    } on DioException catch (e) {
      throw ApiException(
        message: _extractErrorMessage(e) ?? 'Cập nhật hồ sơ thất bại.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> finalizeNewUserSession() async {
    final fn = _userPrefs.tempFirstName ?? '';
    final ln = _userPrefs.tempLastName ?? '';
    final ph = _userPrefs.tempPhone ?? '';

    await refreshProfile();

    if (fn.isNotEmpty || ln.isNotEmpty || ph.isNotEmpty) {
      await updateProfile(firstName: fn, lastName: ln, phoneNumber: ph);
      await refreshProfile();
    }

    await _userPrefs.clearTempRegister();
    await _userPrefs.clearPendingRole();
  }

  Future<void> clearSession() async {
    await _tokenStorage.delete();
    await _userPrefs.clearSessionKeys();
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final msg = strField(
        pickField(map, 'message', ['Message', 'detail', 'title']),
      );
      if (msg.isNotEmpty) return msg;
    }
    if (data is List) {
      return data
          .map((item) {
            if (item is Map) {
              return strField(item['description'] ?? item['message']);
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return null;
  }
}
