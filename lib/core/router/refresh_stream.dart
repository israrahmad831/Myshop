import 'dart:async';
import 'package:flutter/foundation.dart';

/// Adapts a [Stream] into a [Listenable] so GoRouter re-evaluates redirects
/// whenever the stream (e.g. auth state) emits.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
