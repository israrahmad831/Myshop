import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../network/connectivity.dart';
import '../providers/core_providers.dart';
import 'outbox.dart';

/// Replays queued offline mutations to Supabase when connectivity returns.
///
/// Ordering is preserved (FIFO). Insert payloads carry the client-generated
/// UUID so the row keeps the same id it was optimistically shown with.
class SyncEngine {
  SyncEngine(this._client, this._outbox);
  final SupabaseClient _client;
  final Outbox _outbox;

  bool _running = false;

  Future<void> flush() async {
    if (_running || _outbox.isEmpty) return;
    _running = true;
    try {
      for (final entry in _outbox.pending()) {
        final e = entry.value;
        try {
          switch (e.op) {
            case OutboxOp.insert:
              await _client.from(e.table).upsert(e.payload);
            case OutboxOp.update:
              await _client.from(e.table).update(e.payload).eq('id', e.id);
            case OutboxOp.delete:
              await _client.from(e.table).delete().eq('id', e.id);
          }
          await _outbox.remove(entry.key);
        } catch (_) {
          // Stop on first failure; retry on the next connectivity event so we
          // don't drop mutations or reorder them.
          break;
        }
      }
    } finally {
      _running = false;
    }
  }
}

final outboxProvider = Provider<Outbox>((ref) {
  return Outbox(Hive.box<Map>(AppConstants.boxOutbox));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref.watch(supabaseProvider), ref.watch(outboxProvider));
});

/// Watches connectivity and flushes the outbox whenever the device comes back
/// online. Keep this alive for the app's lifetime (read it once at startup).
final syncTriggerProvider = Provider<void>((ref) {
  ref.listen<bool>(isOnlineProvider, (prev, online) {
    if (online == true) ref.read(syncEngineProvider).flush();
  });
});
