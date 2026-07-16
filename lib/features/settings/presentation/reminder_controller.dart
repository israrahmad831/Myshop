import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/core_providers.dart';

/// Persists the "daily khata reminder" toggle and drives the OS scheduling.
class KhataReminderController extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(prefsBoxProvider).get(
          AppConstants.prefKhataReminders,
          defaultValue: false,
        ) as bool;
  }

  Future<void> set(bool enabled) async {
    final service = ref.read(notificationServiceProvider);
    if (enabled) {
      await service.requestPermissions();
      await service.enableDailyReminder();
    } else {
      await service.disableDailyReminder();
    }
    state = enabled;
    await ref
        .read(prefsBoxProvider)
        .put(AppConstants.prefKhataReminders, enabled);
  }
}

final khataReminderProvider =
    NotifierProvider<KhataReminderController, bool>(KhataReminderController.new);
