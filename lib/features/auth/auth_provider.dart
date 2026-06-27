import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/storage/user_prefs.dart';
import '../../core/utils/user_display.dart';
import '../../models/user_profile.dart';
import '../../repositories/auth_repository.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final userPrefsProvider = Provider<UserPrefs>((ref) {
  throw UnimplementedError('UserPrefs must be overridden in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () {
      // Defer to avoid notifying listeners during an in-flight build.
      Future.microtask(() {
        ref.read(authControllerProvider.notifier).handleUnauthorized();
      });
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final prefs = ref.watch(userPrefsProvider);
  return AuthRepository(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    userPrefs: prefs,
  );
});

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.initialized = false,
  });

  final UserProfile? user;
  final bool isLoading;
  final bool initialized;

  bool get isLoggedIn => user != null;

  String get userRole => resolveUserRole(user?.raw);

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    bool? initialized,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);
  UserPrefs? _prefs;

  Future<UserPrefs> _ensurePrefs() async {
    _prefs ??= _ref.read(userPrefsProvider);
    return _prefs!;
  }

  Future<void> bootstrap() async {
    if (state.initialized) return;
    final token = await _repo.getToken();
    UserProfile? user;
    if (token != null && token.isNotEmpty) {
      user = await _repo.getCachedUser();
      user = await _repo.refreshProfile() ?? user;
    }
    state = AuthState(user: user, initialized: true, isLoading: false);
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _repo.login(
        LoginRequest(emailPhoneorUsername: identifier.trim(), password: password),
      );
      UserProfile? user = response.user;
      user ??= await _repo.refreshProfile();
      state = AuthState(user: user, initialized: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> register(RegisterRequest request) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.register(request);
      final prefs = await _ensurePrefs();
      await prefs.saveTempRegister(
        email: request.email,
        password: request.password,
        userName: request.userName,
        firstName: request.firstName ?? '',
        lastName: request.lastName ?? '',
        phone: request.phoneNumber ?? '',
        role: request.role,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> verifyOtpAndLogin(String otp) async {
    final prefs = await _ensurePrefs();
    final email = prefs.tempEmail;
    final password = prefs.tempPassword;
    if (email == null || email.isEmpty) {
      throw Exception('Không tìm thấy email đăng ký.');
    }

    state = state.copyWith(isLoading: true);
    try {
      await _repo.verifyEmailOtp(email, otp);
      if (password != null && password.isNotEmpty) {
        await _repo.login(
          LoginRequest(emailPhoneorUsername: email, password: password),
        );
        await _repo.finalizeNewUserSession();
        final user = await _repo.refreshProfile();
        state = AuthState(user: user, initialized: true, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.clearSession();
    state = const AuthState(initialized: true, isLoading: false);
  }

  Future<void> refreshProfile() async {
    final user = await _repo.refreshProfile();
    state = state.copyWith(user: user);
  }

  Future<void> handleUnauthorized() async {
    await _repo.clearSession();
    state = const AuthState(initialized: true, isLoading: false);
  }

  Future<void> refreshUser() async {
    final user = await _repo.refreshProfile();
    state = state.copyWith(user: user, clearUser: user == null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
