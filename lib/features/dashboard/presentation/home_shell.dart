import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity.dart';
import '../../customers/presentation/customers_list_screen.dart';
import '../../khata/presentation/khata_list_screen.dart';
import '../../products/presentation/products_list_screen.dart';
import '../../receipts/presentation/receipts_list_screen.dart';
import '../../shops/presentation/shop_providers.dart';
import 'dashboard_screen.dart';

/// The main tabbed container shown once a shop is active. Owns the single
/// shared top app bar (search / reports / switch-shop / settings) so those
/// actions appear on every tab.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index = widget.initialTab;

  static const _tabs = <Widget>[
    DashboardScreen(),
    ProductsListScreen(),
    ReceiptsListScreen(),
    CustomersListScreen(),
    KhataListScreen(),
  ];

  static const _titles = ['Home', 'Products', 'Receipts', 'Customers', 'Khata'];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Products'),
    NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Receipts'),
    NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Customers'),
    NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: 'Khata'),
  ];

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final shop = ref.watch(currentShopProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_titles[_index],
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            if (shop != null)
              Text(shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: 'Reports',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/reports'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              switch (v) {
                case 'switch':
                  await ref.read(currentShopIdProvider.notifier).select(null);
                  if (context.mounted) context.go('/shops');
                case 'members':
                  if (context.mounted) context.push('/members');
                case 'settings':
                  if (context.mounted) context.push('/settings');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'switch',
                child: ListTile(
                    leading: Icon(Icons.swap_horiz),
                    title: Text('Switch shop'),
                    contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'members',
                child: ListTile(
                    leading: Icon(Icons.people_outline),
                    title: Text('Members'),
                    contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Settings'),
                    contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!online) const _OfflineBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 16, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Text('Offline — changes will sync when back online',
                  style: TextStyle(
                      color: scheme.onErrorContainer, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
