import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../domain/product.dart';
import 'product_providers.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredProductsProvider);
    final categories = ref.watch(productCategoriesProvider);
    final filter = ref.watch(productFilterProvider);
    final shop = ref.watch(currentShopProvider);
    final canManage = shop?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(productsProvider),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search products…',
              leading: const Icon(Icons.search),
              onChanged: (v) => ref
                  .read(productFilterProvider.notifier)
                  .update((s) => s.copyWith(query: v)),
            ),
          ),
          if (categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: filter.category == null,
                      onSelected: (_) => ref
                          .read(productFilterProvider.notifier)
                          .update((s) => s.copyWith(clearCat: true)),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c),
                        selected: filter.category == c,
                        onSelected: (_) => ref
                            .read(productFilterProvider.notifier)
                            .update((s) => s.copyWith(category: c)),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: AsyncView<List<Product>>(
              value: filtered,
              onRetry: () => ref.invalidate(productsProvider),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products',
                    subtitle: canManage
                        ? 'Add your first product to look up prices fast.'
                        : 'No products have been added yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ProductTile(
                      product: products[i],
                      currency: shop?.currency ?? 'PKR',
                    ),
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.currency});
  final Product product;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => context.push('/products/${product.id}'),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: scheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_outlined),
                  )
                : Container(
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
          ),
        ),
        title: Text(product.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (product.brand != null) product.brand,
          '${Formatters.qty(product.currentStock)} ${product.unit}',
        ].whereType<String>().join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Formatters.money(product.sellingPrice, currency),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: scheme.primary)),
            if (product.currentStock <= AppConstants.lowStockThreshold)
              Text('Low stock',
                  style: TextStyle(fontSize: 11, color: scheme.error)),
          ],
        ),
      ),
    );
  }
}
