import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the device's online/offline status. Used by the sync engine and the
/// UI (offline banner).
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  bool isOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  yield isOnline(await conn.checkConnectivity());
  yield* conn.onConnectivityChanged.map(isOnline);
});

/// Synchronous best-effort read of the latest connectivity value.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).valueOrNull ?? true;
});
