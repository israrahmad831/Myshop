import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock.dart';

/// Wraps the whole app. When app lock is enabled, shows a full-screen lock
/// overlay on cold start and whenever the app returns from the background,
/// requiring biometric / device-credential auth to continue.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(appLockEnabledProvider)) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLockEnabledProvider)) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_locked && mounted) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _tryUnlock();
    }
  }

  Future<void> _tryUnlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await ref
        .read(appLockServiceProvider)
        .authenticate('Unlock Shop Manager');
    _authenticating = false;
    if (mounted && ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked) _LockOverlay(onUnlock: _tryUnlock),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Material(
        color: scheme.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Locked', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Authenticate to continue'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
