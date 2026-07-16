import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/shop.dart';

class ShopsRepository {
  ShopsRepository(this._client);
  final SupabaseClient _client;

  /// Returns every shop the current user is a member of, with their role.
  Future<List<Shop>> myShops() async {
    try {
      final userId = _client.auth.currentUser!.id;
      // shop_members joined to shops; role comes from membership row.
      final rows = await _client
          .from(AppConstants.tblShopMembers)
          .select('role, shops(*)')
          .eq('user_id', userId);

      return (rows as List)
          .where((r) => r['shops'] != null)
          .map((r) => Shop.fromJson(
                (r['shops'] as Map).cast<String, dynamic>(),
                role: r['role'] as String?,
              ))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<Shop> createShop(Shop shop) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final row = await _client
          .from(AppConstants.tblShops)
          .insert(shop.toInsert(userId))
          .select()
          .single();
      // Owner is auto-added as a member by a DB trigger.
      return Shop.fromJson(row, role: 'owner');
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<Shop> updateShop(Shop shop) async {
    try {
      final row = await _client
          .from(AppConstants.tblShops)
          .update(shop.toUpdate())
          .eq('id', shop.id)
          .select()
          .single();
      return Shop.fromJson(row, role: shop.role);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> deleteShop(String shopId) async {
    try {
      await _client.from(AppConstants.tblShops).delete().eq('id', shopId);
    } catch (e) {
      throw mapError(e);
    }
  }
}

final shopsRepositoryProvider = Provider<ShopsRepository>((ref) {
  return ShopsRepository(ref.watch(supabaseProvider));
});
