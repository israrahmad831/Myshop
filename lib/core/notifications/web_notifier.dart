// Web implementation of instant browser notifications (only compiled on web,
// selected via a conditional import). Uses the browser Notification API.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool get webNotificationsSupported => html.Notification.supported;

Future<bool> webRequestPermission() async {
  if (!html.Notification.supported) return false;
  if (html.Notification.permission == 'granted') return true;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

/// Shows a browser notification. Only visible while the site has permission;
/// browsers cannot schedule background/daily notifications without push
/// infrastructure, so recurring reminders remain mobile-only.
Future<void> webShowNotification(String title, String body) async {
  if (!html.Notification.supported) return;
  if (html.Notification.permission != 'granted') {
    final ok = await webRequestPermission();
    if (!ok) return;
  }
  html.Notification(title, body: body);
}
