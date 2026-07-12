import 'lifestyle_display.dart';
import 'user_display.dart';

const createListingPath = '/create-listing';

const tenantAuthPaths = ['/chat'];

bool isTenantAuthPath(String path) {
  final base = path.split('?').first;
  return tenantAuthPaths.any((p) => base == p || base.startsWith('$p/'));
}

String? sanitizeReturnUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final url = raw.trim();
  if (!url.startsWith('/') || url.startsWith('//')) return null;
  final path = url.split('?').first;
  if (path.startsWith('/login') ||
      path.startsWith('/register') ||
      path.startsWith('/auth') ||
      path.startsWith('/otp-verification')) {
    return null;
  }
  return url;
}

String resolvePostLoginUrl(String? returnUrl, {String fallback = '/'}) {
  return sanitizeReturnUrl(returnUrl) ?? fallback;
}

bool isCreateListingReturnUrl(String? url) {
  if (url == null) return false;
  return url.split('?').first == createListingPath;
}

Map<String, String> landlordPostListingQueryParams() => {
      'returnUrl': createListingPath,
      'role': 'landlord',
    };

/// Paths that require completed eKYC (FPT.AI Approved → `isVerified`).
const ekycLandlordPaths = [
  '/landlord-profile',
  '/create-listing',
  '/my-listings',
  '/owner/my-posts',
  '/landlord-pricing',
  '/listing-viewers',
];

/// Redirect to identity verification when logged-in user is not verified yet.
String? ekycVerificationRedirect({
  required bool loggedIn,
  required Map<String, dynamic>? user,
  required String path,
  String? fullLocation,
}) {
  if (!loggedIn || user == null) return null;
  if (path == '/identity-verification') return null;
  if (isAdminUser(user) || isVerifiedUser(user)) return null;

  if (path == '/discovery' && !isLandlordUser(user)) {
    return '/identity-verification?returnUrl=${Uri.encodeComponent('/discovery')}';
  }

  final needsLandlordEkyc = isLandlordUser(user) &&
      ekycLandlordPaths.any((p) => path == p || path.startsWith('$p/'));
  if (needsLandlordEkyc) {
    final returnUrl = sanitizeReturnUrl(fullLocation) ?? '/landlord-profile';
    return '/identity-verification?returnUrl=${Uri.encodeComponent(returnUrl)}';
  }

  return null;
}
