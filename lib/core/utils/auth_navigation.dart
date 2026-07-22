const createListingPath = '/create-listing';

const tenantAuthPaths = ['/chat', '/profile/me'];

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

/// Paths that previously required completed eKYC.
const ekycLandlordPaths = [
  '/landlord-profile',
  '/create-listing',
  '/my-listings',
  '/owner/my-posts',
  '/landlord-pricing',
  '/listing-viewers',
];

/// FPT.AI eKYC discontinued — BE sets IsVerified=true on register; no redirect.
String? ekycVerificationRedirect({
  required bool loggedIn,
  required Map<String, dynamic>? user,
  required String path,
  String? fullLocation,
}) {
  return null;
}
