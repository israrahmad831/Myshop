import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/providers/core_providers.dart';
import '../../shops/presentation/shop_providers.dart';

/// One row of the "top searched products" report.
class TopSearched {
  const TopSearched({required this.name, required this.count});
  final String name;
  final int count;
}

class ReportsRepository {
  ReportsRepository(this._client);
  final SupabaseClient _client;

  Future<List<TopSearched>> topSearched(String shopId, {int limit = 15}) async {
    try {
      final rows = await _client
          .from(AppConstants.tblSearchStats)
          .select('search_count, products(name)')
          .eq('shop_id', shopId)
          .order('search_count', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => (r as Map).cast<String, dynamic>())
          .where((m) => m['products'] != null)
          .map((m) => TopSearched(
                name: (m['products'] as Map)['name'] as String? ?? '—',
                count: (m['search_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(supabaseProvider));
});

/// Top-searched products for the active shop.
final topSearchedProvider =
    FutureProvider.autoDispose<List<TopSearched>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(reportsRepositoryProvider).topSearched(shopId);
});
