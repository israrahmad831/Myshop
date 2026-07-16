import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shops/presentation/shop_providers.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';

/// All products for the active shop.
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(productsRepositoryProvider).list(shopId);
});

/// UI filter state for the product list (search text + category).
class ProductFilter {
  const ProductFilter({this.query = '', this.category});
  final String query;
  final String? category;

  ProductFilter copyWith({String? query, String? category, bool clearCat = false}) =>
      ProductFilter(
        query: query ?? this.query,
        category: clearCat ? null : (category ?? this.category),
      );
}

final productFilterProvider =
    StateProvider.autoDispose<ProductFilter>((ref) => const ProductFilter());

/// Products after applying the current search/category filter.
final filteredProductsProvider =
    Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(productFilterProvider);
  return ref.watch(productsProvider).whenData((products) {
    final q = filter.query.trim().toLowerCase();
    return products.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.brand?.toLowerCase().contains(q) ?? false) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
      final matchesCat =
          filter.category == null || p.category == filter.category;
      return matchesQuery && matchesCat;
    }).toList();
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
