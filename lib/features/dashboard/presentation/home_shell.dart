import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity.dart';
import '../../customers/presentation/customers_list_screen.dart';
import '../../khata/presentation/khata_list_screen.dart';
import '../../products/presentation/products_list_screen.dart';
import '../../receipts/presentation/receipts_list_screen.dart';
import 'dashboard_screen.dart';

/// The main tabbed container shown once a shop is active.
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
    return Scaffold(
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
