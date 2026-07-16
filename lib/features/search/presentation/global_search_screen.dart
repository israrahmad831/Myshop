import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_providers.dart';
import '../../receipts/domain/receipt.dart';
import '../../receipts/presentation/receipt_providers.dart';
import '../../shops/presentation/shop_providers.dart';

/// Global search across products, customers, receipts and khata. Results update
/// instantly as the user types, grouped by type. Works offline (uses caches).
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  ConsumerState<GlobalSearchScreen> createState() =>
      _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Warm caches so search has data immediately.
    Future.microtask(() {
      ref.read(productsProvider);
      ref.read(customersProvider);
      ref.read(receiptsProvider);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final balances = ref.watch(khataBalancesProvider);

    final products = (ref.watch(productsProvider).valueOrNull ?? const [])
        .where((p) =>
            q.isNotEmpty &&
            (p.name.toLowerCase().contains(q) ||
                (p.brand?.toLowerCase().contains(q) ?? false) ||
                (p.barcode?.toLowerCase().contains(q) ?? false)))
        .take(8)
        .toList();
    final customers = (ref.watch(customersProvider).valueOrNull ?? const [])
        .where((c) =>
            q.isNotEmpty &&
            (c.name.toLowerCase().contains(q) ||
                (c.phone?.contains(q) ?? false)))
        .take(8)
        .toList();
    final receipts = (ref.watch(receiptsProvider).valueOrNull ?? const [])
        .where((r) =>
            q.isNotEmpty &&
            (r.receiptNumber.toString().contains(q) ||
                (r.customerName?.toLowerCase().contains(q) ?? false) ||
                (r.customerPhone?.contains(q) ?? false)))
        .take(8)
        .toList();

    final hasResults =
        products.isNotEmpty || customers.isNotEmpty || receipts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search everything…',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search',
              subtitle: 'Find products, customers, receipts and khata.',
            )
          : !hasResults
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No results',
                  subtitle: 'Try a different search term.',
                )
              : ListView(
                  children: [
                    if (products.isNotEmpty) ...[
                      const _GroupHeader('Products'),
                      ...products.map((p) => _productTile(p, currency)),
                    ],
                    if (customers.isNotEmpty) ...[
                      const _GroupHeader('Customers'),
                      ...customers
                          .map((c) => _customerTile(c, balances, currency)),
                    ],
                    if (receipts.isNotEmpty) ...[
                      const _GroupHeader('Receipts'),
                      ...receipts.map((r) => _receiptTile(r, currency)),
                    ],
                  ],
                ),
    );
  }

  Widget _productTile(Product p, String currency) {
    return ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(p.name),
      subtitle: p.brand != null ? Text(p.brand!) : null,
      trailing: Text(Formatters.money(p.sellingPrice, currency)),
      onTap: () {
        final shopId = ref.read(currentShopIdProvider);
        if (shopId != null) {
          ref.read(productsRepositoryProvider).recordSearch(shopId, p.id, _query);
        }
        context.push('/products/${p.id}');
      },
    );
  }

  Widget _customerTile(Customer c, Map<String, num> balances, String currency) {
    final bal = balances[c.id] ?? 0;
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(c.name),
      subtitle: c.phone != null ? Text(c.phone!) : null,
      trailing: bal == 0
          ? null
          : Text(
              Formatters.money(bal.abs(), currency),
              style: TextStyle(
                color: bal > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
      onTap: () => context.push('/customers/${c.id}'),
    );
  }

  Widget _receiptTile(Receipt r, String currency) {
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text('#${r.receiptNumber} · ${r.customerName ?? 'Walk-in'}'),
      subtitle: Text(Formatters.dateTime(r.date)),
      trailing: Text(Formatters.money(r.total, currency)),
      onTap: () => context.push('/receipts/${r.id}'),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
