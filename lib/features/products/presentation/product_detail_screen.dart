import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';
import 'product_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final Product? product = products
        .cast<Product?>()
        .firstWhere((p) => p?.id == productId, orElse: () => null);
    final shop = ref.watch(currentShopProvider);
    final currency = shop?.currency ?? 'PKR';
    final canManage = shop?.canManage ?? false;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Product not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/products/$productId/edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Delete product?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true);
                if (!ok) return;
                await ref
                    .read(productsRepositoryProvider)
                    .delete(productId);
                ref.invalidate(productsProvider);
                if (context.mounted) context.pop();
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (product.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(product.name,
              style: Theme.of(context).textTheme.headlineSmall),
          if (product.brand != null)
            Text(product.brand!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Selling price',
                      Formatters.money(product.sellingPrice, currency)),
                  _row('Purchase price',
                      Formatters.money(product.purchasePrice, currency)),
                  _row('Stock (manual)',
                      '${Formatters.qty(product.currentStock)} ${product.unit}'),
                  if (product.category != null)
                    _row('Category', product.category!),
                  if (product.barcode != null)
                    _row('Barcode', product.barcode!),
                ],
              ),
            ),
          ),
          if (product.description != null &&
              product.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Description',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(product.description!),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
