/// Non-web stub for browser notifications. On mobile/desktop these are handled
/// by flutter_local_notifications instead, so these are no-ops.
bool get webNotificationsSupported => false;

Future<bool> webRequestPermission() async => false;

Future<void> webShowNotification(String title, String body) async {}
