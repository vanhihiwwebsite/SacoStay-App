import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mobile menu open state on `/discovery` — overlays page without shrinking body.
final discoveryMobileMenuOpenProvider = StateProvider<bool>((ref) => false);
