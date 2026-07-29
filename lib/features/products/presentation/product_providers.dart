import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';

/// All products for the active shop.
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(productsRepositoryProvider).list(shopId);
});

enum ProductSort {
  name('Name'),
  priceHigh('Price high'),
  priceLow('Price low'),
  stockLow('Low stock');

  const ProductSort(this.label);
  final String label;
}

/// UI filter state for the product list.
class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.category,
    this.lowStockOnly = false,
    this.sort = ProductSort.name,
  });
  final String query;
  final String? category;
  final bool lowStockOnly;
  final ProductSort sort;

  ProductFilter copyWith({
    String? query,
    String? category,
    bool clearCat = false,
    bool? lowStockOnly,
    ProductSort? sort,
  }) =>
      ProductFilter(
        query: query ?? this.query,
        category: clearCat ? null : (category ?? this.category),
        lowStockOnly: lowStockOnly ?? this.lowStockOnly,
        sort: sort ?? this.sort,
      );
}

final productFilterProvider =
    StateProvider.autoDispose<ProductFilter>((ref) => const ProductFilter());

/// Products after applying the current search/category/stock filter + sort.
final filteredProductsProvider =
    Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(productFilterProvider);
  return ref.watch(productsProvider).whenData((products) {
    final q = filter.query.trim().toLowerCase();
    final list = products.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.brand?.toLowerCase().contains(q) ?? false) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
      final matchesCat =
          filter.category == null || p.category == filter.category;
      final matchesStock = !filter.lowStockOnly ||
          p.currentStock <= AppConstants.lowStockThreshold;
      return matchesQuery && matchesCat && matchesStock;
    }).toList();

    switch (filter.sort) {
      case ProductSort.name:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case ProductSort.priceHigh:
        list.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
      case ProductSort.priceLow:
        list.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
      case ProductSort.stockLow:
        list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    }
    return list;
  });
});

/// Distinct categories present in the shop (for the filter chips).
final productCategoriesProvider = Provider.autoDispose<List<String>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  final cats = products
      .map((p) => p.category)
      .whereType<String>()
      .where((c) => c.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return cats;
});
