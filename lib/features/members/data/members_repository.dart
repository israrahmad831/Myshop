import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/member.dart';

class MembersRepository {
  MembersRepository(this._client);
  final SupabaseClient _client;

  Future<List<ShopMember>> members(String shopId) async {
    try {
      final rows = await _client
          .from(AppConstants.tblShopMembers)
          .select('id, user_id, role, profiles(full_name, email, avatar_url)')
          .eq('shop_id', shopId);
      return (rows as List)
          .map((r) => ShopMember.fromJson((r as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<ShopInvite>> invites(String shopId) async {
    try {
      final rows = await _client
          .from(AppConstants.tblShopInvites)
          .select()
          .eq('shop_id', shopId)
          .eq('status', 'pending');
      return (rows as List)
          .map((r) => ShopInvite.fromJson((r as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> invite(String shopId, String email, String role) async {
    try {
      await _client.from(AppConstants.tblShopInvites).upsert({
        'shop_id': shopId,
        'email': email.trim().toLowerCase(),
        'role': role,
        'status': 'pending',
        'invited_by': _client.auth.currentUser?.id,
      }, onConflict: 'shop_id,email');
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> changeRole(String memberId, String role) async {
    try {
      await _client
          .from(AppConstants.tblShopMembers)
          .update({'role': role}).eq('id', memberId);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Current user leaves a shop (deletes their own membership row). RLS allows
  /// members to delete their own row.
  Future<void> leaveShop(String shopId) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await _client
          .from(AppConstants.tblShopMembers)
          .delete()
          .eq('shop_id', shopId)
          .eq('user_id', uid);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> removeMember(String memberId) async {
    try {
      await _client
          .from(AppConstants.tblShopMembers)
          .delete()
          .eq('id', memberId);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> revokeInvite(String inviteId) async {
    try {
      await _client
          .from(AppConstants.tblShopInvites)
          .delete()
          .eq('id', inviteId);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Pending invites addressed to the current user's email (across all shops).
  /// RLS also allows this; we filter by the signed-in email.
  Future<List<({String id, String shopName, String role})>>
      myPendingInvites() async {
    try {
      final email = _client.auth.currentUser?.email?.toLowerCase();
      if (email == null) return const [];
      final rows = await _client
          .from(AppConstants.tblShopInvites)
          .select('id, role, shops(name)')
          .eq('email', email)
          .eq('status', 'pending');
      return (rows as List).map((r) {
        final m = (r as Map).cast<String, dynamic>();
        return (
          id: m['id'] as String,
          shopName: (m['shops'] as Map?)?['name'] as String? ?? 'Shop',
          role: m['role'] as String,
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Accept an invite (called by the invited user) via the RPC.
  Future<String> acceptInvite(String inviteId) async {
    try {
      final res = await _client.rpc(AppConstants.rpcAcceptInvite,
          params: {'p_invite': inviteId});
      return res as String;
    } catch (e) {
      throw mapError(e);
    }
  }
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository(ref.watch(supabaseProvider));
});
