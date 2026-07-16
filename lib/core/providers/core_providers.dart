import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// The single Supabase client, exposed to the whole app via Riverpod.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// The Hive prefs box (last shop id, theme mode, etc.).
final prefsBoxProvider = Provider<Box>((ref) {
  return Hive.box(AppConstants.boxPrefs);
});
