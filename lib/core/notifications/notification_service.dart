import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_notifier_stub.dart'
    if (dart.library.html) 'web_notifier.dart' as web;

/// Local notifications for optional unpaid-khata reminders.
///
/// Fully **web-safe**: `flutter_local_notifications` has no web implementation,
/// so every method is a no-op when running on the web (or if the platform
/// plugin is missing), and never throws.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  // Stable notification ids.
  static const int _dailyReminderId = 1001;
  static const int _instantId = 1002;

  static const _channel = AndroidNotificationChannel(
    'khata_reminders',
    'Khata reminders',
    description: 'Reminders about unpaid customer khata',
    importance: Importance.defaultImportance,
  );

  bool get _supported => !kIsWeb;

  /// Instant notifications are available on web (browser Notification API) too.
  bool get instantSupported => kIsWeb ? web.webNotificationsSupported : true;

  /// Scheduled/daily reminders are only available on mobile/desktop — browsers
  /// cannot fire background notifications without push infrastructure.
  bool get dailySupported => !kIsWeb;

  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      await _plugin.initialize(const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _ready = true;
    } catch (_) {
      // Plugin unavailable on this platform — stay a no-op.
    }
  }

  /// Ask the OS (or browser) for notification permission.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return web.webRequestPermission();
    if (!_supported) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final a = await android?.requestNotificationsPermission();
      final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return (a ?? i ?? false);
    } catch (_) {
      return false;
    }
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      );

  /// Show an immediate reminder (used by "Send reminder now"). Works on web
  /// (browser notification) and mobile/desktop (local notification).
  Future<void> showNow(String title, String body) async {
    if (kIsWeb) {
      await web.webShowNotification(title, body);
      return;
    }
    if (!_supported) return;
    await init();
    try {
      await _plugin.show(_instantId, title, body, _details);
    } catch (_) {}
  }

  /// Enable a daily repeating reminder. Uses [RepeatInterval.daily] so no
  /// timezone database is required.
  Future<void> enableDailyReminder({
    String title = 'Khata reminder',
    String body = 'Check customers who still owe you money.',
  }) async {
    if (!_supported) return;
    await init();
    try {
      await _plugin.periodicallyShow(
        _dailyReminderId,
        title,
        body,
        RepeatInterval.daily,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> disableDailyReminder() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_dailyReminderId);
    } catch (_) {}
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
