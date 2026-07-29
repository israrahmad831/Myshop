import 'package:equatable/equatable.dart';

/// A shop owned by a user. All app data is scoped to a shop.
class Shop extends Equatable {
  const Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address,
    this.phone,
    this.logoUrl,
    this.currency = 'PKR',
    this.receiptFooter,
    this.receiptHeaderUrl,
    this.ownerName,
    this.role,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final String currency;
  final String? receiptFooter;

  /// Banner image shown at the top of printed receipts.
  final String? receiptHeaderUrl;

  /// Owner name shown on the receipt stamp.
  final String? ownerName;

  /// The current user's role in this shop (joined from shop_members).
  final String? role;
  final DateTime? createdAt;

  bool get isOwner => role == 'owner';
  bool get canManage => role == 'owner' || role == 'admin';
  bool get canCreateReceipts =>
      role == 'owner' || role == 'admin' || role == 'staff';

  factory Shop.fromJson(Map<String, dynamic> json, {String? role}) => Shop(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        logoUrl: json['logo_url'] as String?,
        currency: (json['currency'] as String?) ?? 'PKR',
        receiptFooter: json['receipt_footer'] as String?,
        receiptHeaderUrl: json['receipt_header_url'] as String?,
        ownerName: json['owner_name'] as String?,
        role: role ?? json['role'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toInsert(String ownerId) => {
        'owner_id': ownerId,
        'name': name,
        'address': address,
        'phone': phone,
        'logo_url': logoUrl,
        'currency': currency,
        'receipt_footer': receiptFooter,
        'receipt_header_url': receiptHeaderUrl,
        'owner_name': ownerName,
      };

  Map<String, dynamic> toUpdate() => {
        'name': name,
        'address': address,
        'phone': phone,
        'logo_url': logoUrl,
        'currency': currency,
        'receipt_footer': receiptFooter,
        'receipt_header_url': receiptHeaderUrl,
        'owner_name': ownerName,
      };

  Shop copyWith({
    String? name,
    String? address,
    String? phone,
    String? logoUrl,
    String? currency,
    String? receiptFooter,
    String? receiptHeaderUrl,
    String? ownerName,
    String? role,
  }) =>
      Shop(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        logoUrl: logoUrl ?? this.logoUrl,
        currency: currency ?? this.currency,
        receiptFooter: receiptFooter ?? this.receiptFooter,
        receiptHeaderUrl: receiptHeaderUrl ?? this.receiptHeaderUrl,
        ownerName: ownerName ?? this.ownerName,
        role: role ?? this.role,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, name, role, currency, receiptHeaderUrl, ownerName];
}
