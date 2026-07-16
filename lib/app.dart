import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/local/sync_engine.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_providers.dart';

class ShopManagerApp extends ConsumerWidget {
  const ShopManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isConfigured) return const _MissingConfigApp();

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    // Keep the offline outbox sync engine alive for the app's lifetime.
    ref.watch(syncTriggerProvider);

    // Route to the reset-password screen when a recovery deep link arrives.
    ref.listen(authStateChangesProvider, (_, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        router.go('/reset-password');
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// Shown when SUPABASE_URL / SUPABASE_ANON_KEY were not provided at build time.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Supabase is not configured.\n\n'
              'Run the app with:\n'
              '--dart-define=SUPABASE_URL=...\n'
              '--dart-define=SUPABASE_ANON_KEY=...\n\n'
              'See README.md for full setup.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
