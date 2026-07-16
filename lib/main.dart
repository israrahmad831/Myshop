import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/local/hive_boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local cache first so the app works offline from the very first frame.
  await HiveBoot.init();

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // The publishable ("anon") key — safe to expose in a client.
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(const ProviderScope(child: ShopManagerApp()));
}
