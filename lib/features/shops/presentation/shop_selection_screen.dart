import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/shop.dart';
import 'shop_providers.dart';

/// Lists the user's shops so they can pick one. Shown only when the user has
/// more than one shop (single-shop users are auto-routed to the dashboard).
class ShopSelectionScreen extends ConsumerWidget {
  const ShopSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(myShopsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a shop'),
        actions: [
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
      body: AsyncView<List<Shop>>(
        value: shopsAsync,
        onRetry: () => ref.invalidate(myShopsProvider),
        data: (shops) {
          if (shops.isEmpty) {
            return EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No shops yet',
              subtitle: 'Create your first shop to get started.',
              action: FilledButton.icon(
                onPressed: () => context.push('/shops/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create shop'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final shop = shops[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundImage: shop.logoUrl != null
                        ? NetworkImage(shop.logoUrl!)
                        : null,
                    child: shop.logoUrl == null
                        ? Text(shop.name.characters.first.toUpperCase())
                        : null,
                  ),
                  title: Text(shop.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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
              );
            },
          );
        },
      ),
    );
  }
}
