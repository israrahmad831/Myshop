import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/local/outbox.dart';
import '../../../core/local/sync_engine.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/receipt.dart';

/// Repository for receipts + their line items. Receipts are independent records
/// and never modify inventory or khata.
class ReceiptsRepository {
  ReceiptsRepository({
    required this.client,
    required this.box,
    required this.outbox,
    required this.isOnline,
  });

  final SupabaseClient client;
  final Box<Map> box; // caches full receipts (header + embedded items)
  final Outbox outbox;
  final bool isOnline;
  static const _uuid = Uuid();

  Receipt _fromCache(Map m) {
    final map = m.cast<String, dynamic>();
    final items = ((map['_items'] as List?) ?? const [])
        .map((e) => ReceiptItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return Receipt.fromJson(map, items: items);
  }

  Map<String, dynamic> _toCache(Receipt r) => {
        ...r.toHeaderJson(),
        '_items': r.items
            .map((i) => i.toJson(receiptId: r.id, shopId: r.shopId))
            .toList(),
      };

  List<Receipt> _cachedForShop(String shopId) {
    return box.values
        .where((m) => m['shop_id'] == shopId)
        .map(_fromCache)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// List receipts (with items) for a shop. Falls back to cache when offline.
  Future<List<Receipt>> list(String shopId) async {
    if (!isOnline) return _cachedForShop(shopId);
    try {
      final headers = await client
          .from(AppConstants.tblReceipts)
          .select()
          .eq('shop_id', shopId)
          .order('date', ascending: false);
      final itemRows = await client
          .from(AppConstants.tblReceiptItems)
          .select()
          .eq('shop_id', shopId);

      final itemsByReceipt = <String, List<ReceiptItem>>{};
      for (final row in itemRows as List) {
        final m = (row as Map).cast<String, dynamic>();
        itemsByReceipt
            .putIfAbsent(m['receipt_id'] as String, () => [])
            .add(ReceiptItem.fromJson(m));
      }

      final receipts = (headers as List).map((row) {
        final m = (row as Map).cast<String, dynamic>();
        return Receipt.fromJson(m, items: itemsByReceipt[m['id']] ?? const []);
      }).toList();

      // Refresh cache for this shop.
      final staleKeys = box.keys
          .where((k) => box.get(k)?['shop_id'] == shopId)
          .toList();
      await box.deleteAll(staleKeys);
      await box.putAll({for (final r in receipts) r.id: _toCache(r)});
      return receipts;
    } catch (_) {
      return _cachedForShop(shopId);
    }
  }

  Receipt? getCached(String id) {
    final m = box.get(id);
    return m == null ? null : _fromCache(m);
  }

  int _nextLocalNumber(String shopId) {
    final nums = box.values
        .where((m) => m['shop_id'] == shopId)
        .map((m) => (m['receipt_number'] as num?)?.toInt() ?? 0);
    return (nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b)) + 1;
  }

  /// Creates a receipt and its items. Online: the DB assigns the receipt
  /// number. Offline: a temporary local number is shown and the mutation is
  /// queued (the server re-assigns the definitive number on sync).
  Future<Receipt> create(Receipt draft) async {
    final id = draft.id.isNotEmpty ? draft.id : _uuid.v4();
    // Ensure every item has a stable id for its DB row.
    final items = [
      for (final it in draft.items)
        it.id.isEmpty
            ? ReceiptItem(
                id: _uuid.v4(),
                productId: it.productId,
                productName: it.productName,
                quantity: it.quantity,
                price: it.price,
                discount: it.discount,
              )
            : it,
    ];

    final receipt = Receipt(
      id: id,
      shopId: draft.shopId,
      // Online: DB trigger assigns the number. Offline: temporary local number.
      receiptNumber: isOnline ? 0 : _nextLocalNumber(draft.shopId),
      date: draft.date,
      customerId: draft.customerId,
      customerName: draft.customerName,
      customerPhone: draft.customerPhone,
      discount: draft.discount,
      note: draft.note,
      items: items,
    );

    if (!isOnline) {
      await box.put(id, _toCache(receipt));
      await outbox.enqueue(OutboxEntry(
        id: id,
        table: AppConstants.tblReceipts,
        op: OutboxOp.insert,
        payload: receipt.toHeaderJson()..remove('receipt_number'),
        createdAt: DateTime.now(),
      ));
      for (final it in items) {
        await outbox.enqueue(OutboxEntry(
          id: it.id,
          table: AppConstants.tblReceiptItems,
          op: OutboxOp.insert,
          payload: it.toJson(receiptId: id, shopId: receipt.shopId),
          createdAt: DateTime.now(),
        ));
      }
      return receipt;
    }

    try {
      final header = await client
          .from(AppConstants.tblReceipts)
          .insert(receipt.toHeaderJson())
          .select()
          .single();
      if (items.isNotEmpty) {
        await client.from(AppConstants.tblReceiptItems).insert([
          for (final it in items)
            it.toJson(receiptId: id, shopId: receipt.shopId),
        ]);
      }
      final saved = Receipt.fromJson(header.cast<String, dynamic>(),
          items: items);
      await box.put(id, _toCache(saved));
      return saved;
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> delete(String id) async {
    await box.delete(id);
    if (!isOnline) {
      await outbox.enqueue(OutboxEntry(
        id: id,
        table: AppConstants.tblReceipts,
        op: OutboxOp.delete,
        payload: const {},
        createdAt: DateTime.now(),
      ));
      return;
    }
    try {
      // receipt_items cascade-delete via FK.
      await client.from(AppConstants.tblReceipts).delete().eq('id', id);
    } catch (e) {
      throw mapError(e);
    }
  }
}

final receiptsRepositoryProvider = Provider<ReceiptsRepository>((ref) {
  return ReceiptsRepository(
    client: ref.watch(supabaseProvider),
    box: Hive.box<Map>(AppConstants.boxReceipts),
    outbox: ref.watch(outboxProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
});
