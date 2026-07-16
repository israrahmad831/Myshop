import 'package:equatable/equatable.dart';

/// A single line on a receipt. Snapshots the product name/price so later edits
/// to the product don't change historical receipts. Receipts NEVER touch stock.
class ReceiptItem extends Equatable {
  const ReceiptItem({
    required this.id,
    required this.productName,
    this.productId,
    this.quantity = 1,
    this.price = 0,
    this.discount = 0,
  });

  final String id;
  final String? productId;
  final String productName;
  final num quantity;
  final num price;
  final num discount;

  num get lineTotal => (quantity * price) - discount;

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
        id: j['id'] as String,
        productId: j['product_id'] as String?,
        productName: j['product_name'] as String,
        quantity: (j['quantity'] as num?) ?? 1,
        price: (j['price'] as num?) ?? 0,
        discount: (j['discount'] as num?) ?? 0,
      );

  Map<String, dynamic> toJson({
    required String receiptId,
    required String shopId,
  }) =>
      {
        'id': id,
        'receipt_id': receiptId,
        'shop_id': shopId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'price': price,
        'discount': discount,
        'line_total': lineTotal,
      };

  ReceiptItem copyWith({
    String? productName,
    String? productId,
    num? quantity,
    num? price,
    num? discount,
  }) =>
      ReceiptItem(
        id: id,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        discount: discount ?? this.discount,
      );

  @override
  List<Object?> get props =>
      [id, productId, productName, quantity, price, discount];
}

/// A receipt is an independent record (no effect on inventory or khata).
class Receipt extends Equatable {
  const Receipt({
    required this.id,
    required this.shopId,
    required this.receiptNumber,
    required this.date,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.discount = 0,
    this.note,
    this.items = const [],
  });

  final String id;
  final String shopId;
  final int receiptNumber;
  final DateTime date;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final num discount; // receipt-level discount
  final String? note;
  final List<ReceiptItem> items;

  num get subtotal =>
      items.fold<num>(0, (sum, item) => sum + item.lineTotal);
  num get total => subtotal - discount;

  factory Receipt.fromJson(Map<String, dynamic> j,
          {List<ReceiptItem> items = const []}) =>
      Receipt(
        id: j['id'] as String,
        shopId: j['shop_id'] as String,
        receiptNumber: (j['receipt_number'] as num?)?.toInt() ?? 0,
        date: DateTime.parse(j['date'] as String),
        customerId: j['customer_id'] as String?,
        customerName: j['customer_name'] as String?,
        customerPhone: j['customer_phone'] as String?,
        discount: (j['discount'] as num?) ?? 0,
        note: j['note'] as String?,
        items: items,
      );

  /// Header row for the `receipts` table (items are inserted separately).
  Map<String, dynamic> toHeaderJson() => {
        'id': id,
        'shop_id': shopId,
        // receipt_number is assigned by a DB trigger when null/0.
        if (receiptNumber > 0) 'receipt_number': receiptNumber,
        'date': date.toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'discount': discount,
        'subtotal': subtotal,
        'total': total,
        'note': note,
      };

  Receipt copyWith({
    int? receiptNumber,
    DateTime? date,
    String? customerId,
    String? customerName,
    String? customerPhone,
    num? discount,
    String? note,
    List<ReceiptItem>? items,
  }) =>
      Receipt(
        id: id,
        shopId: shopId,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        date: date ?? this.date,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        discount: discount ?? this.discount,
        note: note ?? this.note,
        items: items ?? this.items,
      );

  @override
  List<Object?> get props => [id, receiptNumber, date, total, items];
}
