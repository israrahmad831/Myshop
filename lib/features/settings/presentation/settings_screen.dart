import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../members/data/members_repository.dart';
import '../../shops/data/shops_repository.dart';
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
            // Owner can delete the shop; other members can leave it.
            if (shop.isOwner)
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Delete shop',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: const Text('Permanently deletes all its data'),
                onTap: () async {
                  final ok = await confirmDialog(context,
                      title: 'Delete "${shop.name}"?',
                      message:
                          'This permanently deletes the shop and ALL its products, '
                          'customers, receipts and khata. This cannot be undone.',
                      confirmLabel: 'Delete',
                      destructive: true);
                  if (!ok) return;
                  try {
                    await ref
                        .read(shopsRepositoryProvider)
                        .deleteShop(shop.id);
                    await ref.read(currentShopIdProvider.notifier).select(null);
                    ref.invalidate(myShopsProvider);
                    if (context.mounted) {
                      showSnack(context, 'Shop deleted');
                      context.go('/');
                    }
                  } catch (e) {
                    if (context.mounted) showSnack(context, '$e', error: true);
                  }
                },
              )
            else
              ListTile(
                leading: Icon(Icons.logout,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Leave shop',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: const Text('You will lose access to this shop'),
                onTap: () async {
                  final ok = await confirmDialog(context,
                      title: 'Leave "${shop.name}"?',
                      message:
                          'You will no longer be able to access this shop unless '
                          'invited again.',
                      confirmLabel: 'Leave',
                      destructive: true);
                  if (!ok) return;
                  try {
                    await ref
                        .read(membersRepositoryProvider)
                        .leaveShop(shop.id);
                    await ref.read(currentShopIdProvider.notifier).select(null);
                    ref.invalidate(myShopsProvider);
                    if (context.mounted) {
                      showSnack(context, 'Left shop');
                      context.go('/');
                    }
                  } catch (e) {
                    if (context.mounted) showSnack(context, '$e', error: true);
                  }
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

          // Security (mobile only — biometrics/device credential)
          if (!kIsWeb) ...[
            const _SectionLabel('Security'),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('App lock'),
              subtitle: const Text(
                  'Require fingerprint / device unlock to open the app'),
              value: ref.watch(appLockEnabledProvider),
              onChanged: (v) async {
                final ok =
                    await ref.read(appLockEnabledProvider.notifier).set(v);
                if (!ok && context.mounted) {
                  showSnack(
                      context,
                      v
                          ? 'Could not enable — no fingerprint/PIN set up on this device'
                          : 'Failed to update',
                      error: true);
                }
              },
            ),
            const Divider(),
          ],

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
