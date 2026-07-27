import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../members/data/members_repository.dart';
import '../domain/shop.dart';
import 'shop_providers.dart';

/// Pending shop invitations addressed to the signed-in user.
final myPendingInvitesProvider = FutureProvider.autoDispose<
    List<({String id, String shopName, String role})>>((ref) async {
  ref.watch(myShopsProvider); // refresh alongside shops
  return ref.read(membersRepositoryProvider).myPendingInvites();
});

/// Lists the user's shops so they can pick one, and shows any pending
/// invitations to join other people's shops (accept to join).
class ShopSelectionScreen extends ConsumerWidget {
  const ShopSelectionScreen({super.key});

  Future<void> _accept(BuildContext context, WidgetRef ref, String id) async {
    try {
      final shopId = await ref.read(membersRepositoryProvider).acceptInvite(id);
      ref.invalidate(myShopsProvider);
      ref.invalidate(myPendingInvitesProvider);
      await ref.read(currentShopIdProvider.notifier).select(shopId);
      if (context.mounted) {
        showSnack(context, 'Joined shop');
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(myShopsProvider);
    final invitesAsync = ref.watch(myPendingInvitesProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a shop'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => ref.read(themeControllerProvider.notifier).set(
                  themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/shops/new'),
        icon: const Icon(Icons.add),
        label: const Text('New shop'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myShopsProvider);
          ref.invalidate(myPendingInvitesProvider);
        },
        child: AsyncView<List<Shop>>(
          value: shopsAsync,
          onRetry: () => ref.invalidate(myShopsProvider),
          data: (shops) {
            final invites = invitesAsync.valueOrNull ?? const [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Invitations --------------------------------------
                if (invites.isNotEmpty) ...[
                  Text('Invitations',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...invites.map((inv) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.mark_email_unread_outlined),
                          title: Text(inv.shopName),
                          subtitle:
                              Text('Invited as ${inv.role.toUpperCase()}'),
                          trailing: FilledButton(
                            onPressed: () => _accept(context, ref, inv.id),
                            child: const Text('Accept'),
                          ),
                        ),
                      )),
                  const SizedBox(height: 20),
                  Text('Your shops',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],

                // --- Shops --------------------------------------------
                if (shops.isEmpty && invites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No shops yet',
                      subtitle:
                          'Create your first shop, or accept an invitation '
                          'when someone adds you to theirs.',
                      action: FilledButton.icon(
                        onPressed: () => context.push('/shops/new'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create shop'),
                      ),
                    ),
                  )
                else if (shops.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('You have no shops yet. Accept an invite '
                        'above or create one.'),
                  )
                else
                  ...shops.map((shop) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundImage: shop.logoUrl != null
                                ? NetworkImage(shop.logoUrl!)
                                : null,
                            child: shop.logoUrl == null
                                ? Text(shop.name.characters.first
                                    .toUpperCase())
                                : null,
                          ),
                          title: Text(shop.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${shop.role?.toUpperCase() ?? ''} · ${shop.currency}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await ref
                                .read(currentShopIdProvider.notifier)
                                .select(shop.id);
                            if (context.mounted) context.go('/');
                          },
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
