import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// A single mutation queued while offline, replayed on reconnect.
enum OutboxOp { insert, update, delete }

class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.table,
    required this.op,
    required this.payload,
    required this.createdAt,
  });

  final String id; // == the row id being mutated
  final String table;
  final OutboxOp op;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'table': table,
        'op': op.name,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory OutboxEntry.fromMap(Map m) => OutboxEntry(
        id: m['id'] as String,
        table: m['table'] as String,
        op: OutboxOp.values.byName(m['op'] as String),
        payload: (m['payload'] as Map).cast<String, dynamic>(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// FIFO queue of pending offline mutations, persisted in Hive.
class Outbox {
  Outbox(this._box);
  final Box<Map> _box;
  static const _uuid = Uuid();

  bool get isEmpty => _box.isEmpty;
  int get length => _box.length;

  Future<void> enqueue(OutboxEntry entry) async {
    // Unique queue key so multiple edits to one row are preserved in order.
    await _box.put('${entry.createdAt.microsecondsSinceEpoch}_${_uuid.v4()}',
        entry.toMap());
  }

  /// Entries oldest-first.
  List<MapEntry<dynamic, OutboxEntry>> pending() {
    final list = _box.keys
        .map((k) => MapEntry(k, OutboxEntry.fromMap(_box.get(k)!)))
        .toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
    return list;
  }

  Future<void> remove(dynamic key) async => _box.delete(key);
}
