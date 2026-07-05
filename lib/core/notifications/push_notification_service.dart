/// Stub for Firebase Cloud Messaging — wire up when `google-services.json`
/// and `firebase_messaging` are configured.
///
/// Phase 5 checklist:
/// 1. Add firebase_core + firebase_messaging to pubspec.yaml
/// 2. Register device token with backend endpoint (when available)
/// 3. Handle foreground/background notification taps → deep links
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  bool _initialized = false;

  bool get isAvailable => false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // FCM not configured in this build — REST /Notification API is used instead.
  }

  Future<String?> getDeviceToken() async => null;

  Future<void> subscribeToUserTopics({required String userId}) async {}

  Future<void> dispose() async {}
}
