import 'package:equatable/equatable.dart';

/// A product record. This module ONLY stores information — nothing here (and no
/// receipt/khata action) ever changes [currentStock] automatically. Stock is a
/// manual field the shopkeeper edits by hand.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.imageUrl,
    this.brand,
    this.category,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.currentStock = 0,
    this.unit = 'pcs',
    this.barcode,
    this.description,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String? imageUrl;
  final String? brand;
  final String? category;
  final num purchasePrice;
  final num sellingPrice;
  final num currentStock; // manual
  final String unit;
  final String? barcode;
  final String? description;
  final DateTime? updatedAt;

  bool get isLowStock => currentStock <= 5;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        shopId: j['shop_id'] as String,
        name: j['name'] as String,
        imageUrl: j['image_url'] as String?,
        brand: j['brand'] as String?,
        category: j['category'] as String?,
        purchasePrice: (j['purchase_price'] as num?) ?? 0,
        sellingPrice: (j['selling_price'] as num?) ?? 0,
        currentStock: (j['current_stock'] as num?) ?? 0,
        unit: (j['unit'] as String?) ?? 'pcs',
        barcode: j['barcode'] as String?,
        description: j['description'] as String?,
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.parse(j['updated_at'] as String),
      );

  /// For Hive cache + Supabase payloads.
  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'name': name,
        'image_url': imageUrl,
        'brand': brand,
        'category': category,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'current_stock': currentStock,
        'unit': unit,
        'barcode': barcode,
        'description': description,
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Payload for insert/update (no server-managed fields).
  Map<String, dynamic> toWrite() => {
        'shop_id': shopId,
        'name': name,
        'image_url': imageUrl,
        'brand': brand,
        'category': category,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'current_stock': currentStock,
        'unit': unit,
        'barcode': barcode,
        'description': description,
      };

  Product copyWith({
    String? name,
    String? imageUrl,
    String? brand,
    String? category,
    num? purchasePrice,
    num? sellingPrice,
    num? currentStock,
    String? unit,
    String? barcode,
    String? description,
  }) =>
      Product(
        id: id,
        shopId: shopId,
        name: name ?? this.name,
        imageUrl: imageUrl ?? this.imageUrl,
        brand: brand ?? this.brand,
        category: category ?? this.category,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        currentStock: currentStock ?? this.currentStock,
        unit: unit ?? this.unit,
        barcode: barcode ?? this.barcode,
        description: description ?? this.description,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [id, name, sellingPrice, currentStock, updatedAt];
}
