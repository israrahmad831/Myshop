import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.shopId,
    required this.amount,
    required this.date,
    this.category,
    this.note,
  });

  final String id;
  final String shopId;
  final num amount;
  final DateTime date;
  final String? category;
  final String? note;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        amount: (json['amount'] as num?) ?? 0,
        date: DateTime.parse(json['date'] as String),
        category: json['category'] as String?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toWrite() => {
        'shop_id': shopId,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'note': note,
      };

  @override
  List<Object?> get props => [id, shopId, amount, date, category, note];
}
