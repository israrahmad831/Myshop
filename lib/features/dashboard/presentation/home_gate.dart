import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../shops/domain/shop.dart';
import '../../shops/presentation/shop_providers.dart';
import '../../shops/presentation/shop_selection_screen.dart';
import 'home_shell.dart';

/// Decides what the user sees at '/':
///   * 0 shops  -> shop selection (with create CTA)
///   * 1 shop   -> auto-select it and open the main shell
///   * >1 shops -> selection unless a last-opened shop is remembered
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(myShopsProvider);
    final currentShop = ref.watch(currentShopProvider);

    // A shop is already active (remembered or just selected).
    if (currentShop != null) return const HomeShell();

    return AsyncView<List<Shop>>(
      value: shopsAsync,
      onRetry: () => ref.invalidate(myShopsProvider),
      data: (shops) {
        if (shops.isEmpty || shops.length > 1) {
          return const ShopSelectionScreen();
        }
        // Exactly one shop — auto-select after this frame, then show shell.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(currentShopIdProvider.notifier).select(shops.first.id);
        });
        return const LoadingView();
      },
    );
  }
}
