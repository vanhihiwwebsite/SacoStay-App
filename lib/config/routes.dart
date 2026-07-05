import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/user_display.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/verify_reset_otp_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/discovery/lifestyle_quiz_screen.dart';
import '../features/home/home_screen.dart';
import '../features/landlord/create_listing_screen.dart';
import '../features/landlord/landlord_pricing_screen.dart';
import '../features/landlord/landlord_profile_screen.dart';
import '../features/landlord/listing_viewers_screen.dart';
import '../features/landlord/my_listings_screen.dart';
import '../features/legal/faq_screen.dart';
import '../features/legal/terms_screen.dart';
import '../features/map/map_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/identity_verification_screen.dart';
import '../features/payment/payment_checkout_screen.dart';
import '../features/payment/payment_config.dart';
import '../features/payment/payment_result_screen.dart';
import '../features/pricing/tenant_pricing_screen.dart';
import '../features/profile/profile_setup_screen.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/rooms/room_detail_screen.dart';
import '../features/rooms/rooms_screen.dart';
import '../shared/widgets/role_shells.dart';
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
          path == '/forgot-password' ||
          path == '/verify-reset-otp' ||
          path == '/reset-password';

      if (!auth.initialized) return null;

      final loggedIn = auth.isLoggedIn;
      final user = auth.user?.raw;

      if (loggedIn && (path == '/login' || path == '/register')) {
        return '/';
      }

      if (loggedIn && path == '/' && isAdminUser(user)) {
        return '/admin';
      }

      final protectedPrefixes = [
        '/chat',
        '/landlord-profile',
        '/create-listing',
        '/my-listings',
        '/owner/my-posts',
        '/landlord-pricing',
        '/listing-viewers',
        '/profile-setup',
        '/profile',
        '/identity-verification',
        '/admin',
        '/notifications',
        '/payment/checkout',
      ];
      final needsAuth = protectedPrefixes.any(
        (p) => path == p || path.startsWith('$p/'),
      );
      if (!loggedIn && needsAuth && !isAuthRoute) {
        final returnUrl = Uri.encodeComponent(state.uri.toString());
        return '/login?returnUrl=$returnUrl';
      }

      if (loggedIn && path.startsWith('/admin') && !isAdminUser(user)) {
        return '/';
      }

      const landlordPaths = [
        '/landlord-profile',
        '/create-listing',
        '/my-listings',
        '/owner/my-posts',
        '/landlord-pricing',
        '/listing-viewers',
      ];
      if (loggedIn &&
          landlordPaths.any((p) => path == p || path.startsWith('$p/')) &&
          !isLandlordUser(user) &&
          !isAdminUser(user)) {
        return '/';
      }

      if (path == '/owner/my-posts') return '/my-listings';
      if (path == '/landlord-chat') return '/chat';

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
      GoRoute(path: '/auth', redirect: (_, __) => '/login'),
      GoRoute(
        path: '/otp-verification',
        builder: (_, __) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const SacoScaffold(body: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/verify-reset-otp',
        builder: (_, __) => const SacoScaffold(body: VerifyResetOtpScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const SacoScaffold(body: ResetPasswordScreen()),
      ),
      GoRoute(
        path: '/discovery',
        builder: (_, __) => const SacoScaffold(body: DiscoveryScreen()),
      ),
      GoRoute(
        path: '/lifestyle-quiz',
        builder: (_, __) => const SacoScaffold(body: LifestyleQuizScreen()),
      ),
      GoRoute(
        path: '/rooms',
        builder: (_, __) => const SacoScaffold(body: RoomsScreen()),
      ),
      GoRoute(
        path: '/rooms/:id',
        builder: (_, state) => SacoScaffold(
          body: RoomDetailScreen(roomId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (_, __) => const SacoScaffold(body: MapScreen()),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, __) => const SacoRouteShell(body: ChatScreen()),
      ),
      GoRoute(
        path: '/landlord-chat',
        redirect: (_, __) => '/chat',
      ),
      GoRoute(
        path: '/tenant-pricing',
        builder: (_, __) => const SacoScaffold(body: TenantPricingScreen()),
      ),
      GoRoute(
        path: '/landlord-profile',
        builder: (_, __) => const LandlordShell(body: LandlordProfileScreen()),
      ),
      GoRoute(
        path: '/my-listings',
        builder: (_, __) => const LandlordShell(body: MyListingsScreen()),
      ),
      GoRoute(
        path: '/owner/my-posts',
        redirect: (_, __) => '/my-listings',
      ),
      GoRoute(
        path: '/create-listing',
        builder: (_, __) => const LandlordShell(body: CreateListingScreen()),
      ),
      GoRoute(
        path: '/landlord-pricing',
        builder: (_, state) => LandlordShell(
          body: LandlordPricingScreen(
            postId: state.uri.queryParameters['postId'] ??
                state.uri.queryParameters['roomPostId'],
          ),
        ),
      ),
      GoRoute(
        path: '/listing-viewers',
        builder: (_, __) => const LandlordShell(body: ListingViewersScreen()),
      ),
      GoRoute(
        path: '/listing-viewers/:id',
        builder: (_, state) => LandlordShell(
          body: ListingViewersScreen(
            initialPostId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/payment/checkout',
        builder: (_, state) {
          final pkg = PaymentCheckoutPackage.fromQuery(
            state.uri.queryParameters['package'],
          );
          final ctx = PaymentContextX.fromQuery(
            state.uri.queryParameters['context'],
          );
          if (pkg == null || ctx == null) {
            return const SacoScaffold(
              body: Center(child: Text('Thông tin thanh toán không hợp lệ')),
            );
          }
          if (ctx == PaymentContext.landlord) {
            return LandlordShell(
              body: PaymentCheckoutScreen(
                package: pkg,
                contextType: ctx,
                postId: state.uri.queryParameters['postId'],
              ),
            );
          }
          return SacoScaffold(
            body: PaymentCheckoutScreen(
              package: pkg,
              contextType: ctx,
              postId: state.uri.queryParameters['postId'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/payment/result',
        builder: (_, state) {
          final ctx = PaymentContextX.fromQuery(
            state.uri.queryParameters['context'],
          );
          final body = PaymentResultScreen(
            status: state.uri.queryParameters['status'] ?? 'unknown',
            contextType: ctx,
            orderId: state.uri.queryParameters['orderId'],
            package: state.uri.queryParameters['package'],
            postId: state.uri.queryParameters['postId'],
          );
          if (ctx == PaymentContext.landlord) {
            return LandlordShell(body: body);
          }
          return SacoScaffold(body: body);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const SacoRouteShell(body: NotificationsScreen()),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const SacoScaffold(body: ProfileSetupScreen()),
      ),
      GoRoute(
        path: '/profile/me',
        builder: (_, __) => const SacoScaffold(body: UserProfileScreen()),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (_, state) => SacoScaffold(
          body: UserProfileScreen(userId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/identity-verification',
        builder: (_, __) => const SacoScaffold(body: IdentityVerificationScreen()),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShell(body: AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/faq',
        builder: (_, __) => const SacoScaffold(body: FaqScreen()),
      ),
      GoRoute(
        path: '/faq/:id',
        builder: (_, state) => SacoScaffold(
          body: FaqDetailScreen(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/roommate-matching',
        redirect: (_, __) => '/faq/roommate-matching',
      ),
      GoRoute(
        path: '/verified-listings',
        redirect: (_, __) => '/faq/verified-listings',
      ),
      GoRoute(
        path: '/help/contact-landlord',
        redirect: (_, __) => '/faq/contact-landlord',
      ),
      GoRoute(
        path: '/help/roommate-support',
        redirect: (_, __) => '/faq/roommate-support',
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => const SacoScaffold(body: TermsScreen()),
      ),
      GoRoute(path: '/privacy', redirect: (_, __) => '/terms'),
      GoRoute(path: '/pricing', redirect: (_, __) => '/tenant-pricing'),
    ],
  );
});
