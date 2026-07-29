import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.imageUrl,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final String? imageUrl;
  final DateTime? updatedAt;

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        shopId: j['shop_id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        notes: j['notes'] as String?,
        imageUrl: j['image_url'] as String?,
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toWrite() => {
        'shop_id': shopId,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'image_url': imageUrl,
      };

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
    String? imageUrl,
  }) =>
      Customer(
        id: id,
        shopId: shopId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        imageUrl: imageUrl ?? this.imageUrl,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, name, phone, address, notes, imageUrl, updatedAt];
}
