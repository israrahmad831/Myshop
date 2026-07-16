import 'package:equatable/equatable.dart';

/// Direction of a khata (ledger) transaction. The signed contribution to the
/// customer's balance is defined in [signedAmount].
enum KhataType {
  udhaarGiven('udhaar_given', 'Udhaar given', 'Customer owes you'),
  paymentReceived('payment_received', 'Payment received', 'Customer paid you'),
  udhaarTaken('udhaar_taken', 'Udhaar taken', 'You owe customer'),
  paymentGiven('payment_given', 'Payment given', 'You paid customer');

  const KhataType(this.db, this.label, this.hint);
  final String db;
  final String label;
  final String hint;

  static KhataType fromDb(String v) =>
      KhataType.values.firstWhere((e) => e.db == v);

  /// + increases what the customer owes the shop (receivable),
  /// - means the shop owes the customer (payable).
  bool get increasesReceivable =>
      this == udhaarGiven || this == paymentGiven;
}

class KhataTransaction extends Equatable {
  const KhataTransaction({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final String shopId;
  final String customerId;
  final KhataType type;
  final num amount;
  final DateTime date;
  final String? note;

  /// Signed contribution to the running balance (+ receivable, - payable).
  num get signedAmount => type.increasesReceivable ? amount : -amount;

  factory KhataTransaction.fromJson(Map<String, dynamic> j) => KhataTransaction(
        id: j['id'] as String,
        shopId: j['shop_id'] as String,
        customerId: j['customer_id'] as String,
        type: KhataType.fromDb(j['type'] as String),
        amount: (j['amount'] as num?) ?? 0,
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
      );

  Map<String, dynamic> toWrite() => {
        'shop_id': shopId,
        'customer_id': customerId,
        'type': type.db,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  KhataTransaction copyWith({
    KhataType? type,
    num? amount,
    DateTime? date,
    String? note,
  }) =>
      KhataTransaction(
        id: id,
        shopId: shopId,
        customerId: customerId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        note: note ?? this.note,
      );

  @override
  List<Object?> get props => [id, type, amount, date, note];
}
