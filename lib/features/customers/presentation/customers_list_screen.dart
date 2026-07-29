import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import '../domain/customer.dart';
import 'customer_providers.dart';

class CustomersListScreen extends ConsumerWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredCustomersProvider);
    final balances = ref.watch(khataBalancesProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final canCreate =
        ref.watch(currentShopProvider)?.canCreateReceipts ?? false;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/customers/new'),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search customers…',
              leading: const Icon(Icons.search),
              onChanged: (v) =>
                  ref.read(customerSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: AsyncView<List<Customer>>(
              value: filtered,
              onRetry: () => ref.invalidate(customersProvider),
              data: (customers) {
                if (customers.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No customers',
                    subtitle: 'Add customers to track khata and receipts.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(customersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = customers[i];
                      final bal = balances[c.id] ?? 0;
                      return Card(
                        child: ListTile(
                          onTap: () => context.push('/customers/${c.id}'),
                          leading: CircleAvatar(
                            backgroundImage: c.imageUrl != null
                                ? NetworkImage(c.imageUrl!)
                                : null,
                            child: c.imageUrl == null
                                ? Text(c.name.characters.first.toUpperCase())
                                : null,
                          ),
                          title: Text(c.name),
                          subtitle: c.phone != null ? Text(c.phone!) : null,
                          trailing: bal == 0
                              ? null
                              : Text(
                                  Formatters.money(bal.abs(), currency),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        bal > 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
