import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/shops_repository.dart';
import '../domain/shop.dart';

/// All shops the signed-in user belongs to. Refetched when auth changes.
final myShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final user = ref.watch(currentUserProvider); // re-run on login/logout
  if (user == null) return const []; // signed out — avoid a null deref
  return ref.watch(shopsRepositoryProvider).myShops();
});

/// The id of the currently active shop. Persisted so we reopen the last shop.
class CurrentShopId extends Notifier<String?> {
  @override
  String? build() {
    return ref.read(prefsBoxProvider).get(AppConstants.prefLastShopId)
        as String?;
  }

  Future<void> select(String? shopId) async {
    state = shopId;
    final box = ref.read(prefsBoxProvider);
    if (shopId == null) {
      await box.delete(AppConstants.prefLastShopId);
    } else {
      await box.put(AppConstants.prefLastShopId, shopId);
    }
  }
}

final currentShopIdProvider =
    NotifierProvider<CurrentShopId, String?>(CurrentShopId.new);

/// The resolved current [Shop] object (null until one is chosen/loaded).
final currentShopProvider = Provider<Shop?>((ref) {
  final id = ref.watch(currentShopIdProvider);
  final shops = ref.watch(myShopsProvider).valueOrNull;
  if (id == null || shops == null) return null;
  for (final s in shops) {
    if (s.id == id) return s;
  }
  return null;
});
