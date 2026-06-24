import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/home/home_screen.dart';
import '../shared/widgets/placeholder_screen.dart';
import '../shared/widgets/saco_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/auth' ||
          path == '/otp-verification' ||
          path == '/forgot-password';

      if (!auth.initialized) return null;

      final loggedIn = auth.isLoggedIn;

      if (loggedIn && (path == '/login' || path == '/register')) {
        return '/';
      }

      final protectedPrefixes = [
        '/chat',
        '/landlord-profile',
        '/create-listing',
        '/my-listings',
        '/profile-setup',
        '/identity-verification',
        '/admin',
      ];
      final needsAuth = protectedPrefixes.any(
        (p) => path == p || path.startsWith('$p/'),
      );
      if (!loggedIn && needsAuth && !isAuthRoute) {
        final returnUrl = Uri.encodeComponent(state.uri.toString());
        return '/login?returnUrl=$returnUrl';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/login',
        builder: (_, __) => const AuthScreen(initialMode: AuthMode.login),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const AuthScreen(initialMode: AuthMode.register),
      ),
      GoRoute(
        path: '/auth',
        redirect: (_, __) => '/login',
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (_, __) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(
            title: 'Quên mật khẩu',
            subtitle: 'Tính năng sẽ được bổ sung trong phiên bản tiếp theo.',
          ),
        ),
      ),
      GoRoute(
        path: '/discovery',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(
            title: 'Tìm bạn ở ghép',
            subtitle: 'Discovery swipe deck — Phase 3.',
          ),
        ),
      ),
      GoRoute(
        path: '/rooms',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(
            title: 'Phòng trọ',
            subtitle: 'Danh sách phòng — Phase 3.',
          ),
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Bản đồ', subtitle: 'Map — Phase 2.'),
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Tin nhắn', subtitle: 'Chat — Phase 3.'),
        ),
      ),
      GoRoute(
        path: '/tenant-pricing',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Bảng giá Premium'),
        ),
      ),
      GoRoute(
        path: '/landlord-profile',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Hồ sơ chủ trọ'),
        ),
      ),
      GoRoute(
        path: '/create-listing',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Đăng tin phòng'),
        ),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Thiết lập hồ sơ'),
        ),
      ),
      GoRoute(
        path: '/identity-verification',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Xác minh danh tính (eKYC)'),
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Admin Dashboard'),
        ),
      ),
      GoRoute(
        path: '/faq',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'FAQ'),
        ),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Điều khoản sử dụng'),
        ),
      ),
      GoRoute(
        path: '/pricing',
        builder: (_, __) => const SacoScaffold(
          body: PlaceholderScreen(title: 'Bảng giá dịch vụ'),
        ),
      ),
    ],
  );
});
