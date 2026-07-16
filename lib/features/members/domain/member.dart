import 'package:equatable/equatable.dart';

/// A member of a shop (a row in shop_members joined to their profile).
class ShopMember extends Equatable {
  const ShopMember({
    required this.id,
    required this.userId,
    required this.role,
    this.fullName,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String userId;
  final String role;
  final String? fullName;
  final String? email;
  final String? avatarUrl;

  factory ShopMember.fromJson(Map<String, dynamic> j) {
    final profile = (j['profiles'] as Map?)?.cast<String, dynamic>();
    return ShopMember(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      role: j['role'] as String,
      fullName: profile?['full_name'] as String?,
      email: profile?['email'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }

  String get displayName => fullName ?? email ?? 'Member';

  @override
  List<Object?> get props => [id, userId, role];
}

/// A pending invite to join a shop.
class ShopInvite extends Equatable {
  const ShopInvite({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
  });

  final String id;
  final String email;
  final String role;
  final String status;

  factory ShopInvite.fromJson(Map<String, dynamic> j) => ShopInvite(
        id: j['id'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        status: j['status'] as String,
      );

  @override
  List<Object?> get props => [id, email, role, status];
}

const kRoles = ['admin', 'staff', 'viewer'];
const kAllRoles = ['owner', 'admin', 'staff', 'viewer'];
