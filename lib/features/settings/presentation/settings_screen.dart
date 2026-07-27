import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import 'reminder_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentShopProvider);
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account
          ListTile(
            leading: CircleAvatar(
              backgroundImage: user?.userMetadata?['avatar_url'] != null
                  ? NetworkImage(user!.userMetadata!['avatar_url'] as String)
                  : null,
              child: user?.userMetadata?['avatar_url'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
                (user?.userMetadata?['full_name'] as String?) ?? 'Account'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),

          // Shop section
          if (shop != null) ...[
            const _SectionLabel('Shop'),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(shop.name),
              subtitle: Text('${shop.role?.toUpperCase()} · ${shop.currency}'),
              trailing: shop.canManage
                  ? const Icon(Icons.edit_outlined)
                  : null,
              onTap: shop.canManage
                  ? () => context.push('/shops/edit', extra: shop)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Members'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/members'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Switch shop'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref.read(currentShopIdProvider.notifier).select(null);
                if (context.mounted) context.go('/shops');
              },
            ),
            const Divider(),
          ],

          // Appearance
          const _SectionLabel('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (m) =>
                ref.read(themeControllerProvider.notifier).set(m!),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('System default'),
                  secondary: Icon(Icons.brightness_auto),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                  secondary: Icon(Icons.light_mode_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                  secondary: Icon(Icons.dark_mode_outlined),
                ),
              ],
            ),
          ),
          const Divider(),

          // Notifications
          const _SectionLabel('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Daily khata reminders'),
            subtitle: const Text(kIsWeb
                ? 'Scheduled reminders need the Android/iOS app'
                : 'Remind me daily about customers who owe money'),
            value: !kIsWeb && ref.watch(khataReminderProvider),
            // Scheduled reminders can't run in a browser tab.
            onChanged: kIsWeb
                ? null
                : (v) => ref.read(khataReminderProvider.notifier).set(v),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Send a reminder now'),
            subtitle: kIsWeb
                ? const Text('Shows a browser notification')
                : null,
            onTap: () async {
              final service = ref.read(notificationServiceProvider);
              final granted = await service.requestPermissions();
              if (!granted) {
                if (context.mounted) {
                  showSnack(context, 'Notification permission not granted',
                      error: true);
                }
                return;
              }
              final totals = ref.read(khataTotalsProvider);
              final currency = shop?.currency ?? 'PKR';
              await service.showNow(
                'Unpaid khata',
                'You will get ${Formatters.money(totals.receivable, currency)} '
                    'from customers.',
              );
              if (context.mounted) {
                showSnack(context, 'Reminder sent');
              }
            },
          ),
          const Divider(),

          // Sign out
          ListTile(
            leading: Icon(Icons.logout,
                color: Theme.of(context).colorScheme.error),
            title: Text('Sign out',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              final ok = await confirmDialog(context,
                  title: 'Sign out?',
                  message: 'You will need to sign in again.',
                  confirmLabel: 'Sign out');
              if (!ok) return;
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}
