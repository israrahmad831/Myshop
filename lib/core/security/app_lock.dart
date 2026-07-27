import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../constants/app_constants.dart';
import '../providers/core_providers.dart';

/// Wraps device biometric / device-credential auth for the optional app lock.
/// No-ops (returns unsupported) on web.
class AppLockService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether the device can do biometric or device-credential auth.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && (canCheck || true); // device credential also allowed
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user. Returns true when authenticated. Falls back to the
  /// device PIN/pattern when biometrics aren't enrolled (biometricOnly: false).
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Persisted "app lock enabled" flag. Enabling requires a successful auth.
class AppLockEnabled extends Notifier<bool> {
  @override
  bool build() {
    if (kIsWeb) return false;
    return ref.read(prefsBoxProvider).get(
          AppConstants.prefAppLock,
          defaultValue: false,
        ) as bool;
  }

  /// Returns true if the new state was applied. When enabling, the user must
  /// pass a biometric/credential check first.
  Future<bool> set(bool enabled) async {
    if (enabled) {
      final service = ref.read(appLockServiceProvider);
      if (!await service.isAvailable()) return false;
      if (!await service.authenticate('Enable app lock')) return false;
    }
    state = enabled;
    await ref.read(prefsBoxProvider).put(AppConstants.prefAppLock, enabled);
    return true;
  }
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabled, bool>(AppLockEnabled.new);
