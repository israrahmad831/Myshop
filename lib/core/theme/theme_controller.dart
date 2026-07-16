import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/core_providers.dart';

/// Persists and exposes the user's light/dark/system preference.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored =
        ref.read(prefsBoxProvider).get(AppConstants.prefThemeMode) as String?;
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsBoxProvider).put(AppConstants.prefThemeMode, mode.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
