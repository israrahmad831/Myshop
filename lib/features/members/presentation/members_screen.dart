import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/members_repository.dart';
import '../domain/member.dart';

final _membersProvider =
    FutureProvider.autoDispose<List<ShopMember>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(membersRepositoryProvider).members(shopId);
});

final _invitesProvider =
    FutureProvider.autoDispose<List<ShopInvite>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(membersRepositoryProvider).invites(shopId);
});

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentShopProvider);
    final isOwner = shop?.isOwner ?? false;
    final membersAsync = ref.watch(_membersProvider);
    final invitesAsync = ref.watch(_invitesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showInviteSheet(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Invite'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_membersProvider);
          ref.invalidate(_invitesProvider);
        },
        child: AsyncView<List<ShopMember>>(
          value: membersAsync,
          onRetry: () => ref.invalidate(_membersProvider),
          data: (members) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Members (${members.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...members.map((m) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: m.avatarUrl != null
                            ? NetworkImage(m.avatarUrl!)
                            : null,
                        child: m.avatarUrl == null
                            ? Text(m.displayName.characters.first
                                .toUpperCase())
                            : null,
                      ),
                      title: Text(m.displayName),
                      subtitle: Text(m.email ?? ''),
                      trailing: isOwner && m.role != 'owner'
                          ? _RoleMenu(
                              current: m.role,
                              onChange: (role) async {
                                await ref
                                    .read(membersRepositoryProvider)
                                    .changeRole(m.id, role);
                                ref.invalidate(_membersProvider);
                              },
                              onRemove: () async {
                                final ok = await confirmDialog(context,
                                    title: 'Remove member?',
                                    message:
                                        '${m.displayName} will lose access.',
                                    confirmLabel: 'Remove',
                                    destructive: true);
                                if (!ok) return;
                                await ref
                                    .read(membersRepositoryProvider)
                                    .removeMember(m.id);
                                ref.invalidate(_membersProvider);
                              },
                            )
                          : Chip(label: Text(m.role.toUpperCase())),
                    ),
                  )),
              const SizedBox(height: 16),
              invitesAsync.maybeWhen(
                data: (invites) => invites.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pending invites',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...invites.map((inv) => Card(
                                child: ListTile(
                                  leading: const Icon(Icons.mail_outline),
                                  title: Text(inv.email),
                                  subtitle: Text(inv.role.toUpperCase()),
                                  trailing: isOwner
                                      ? IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () async {
                                            await ref
                                                .read(
                                                    membersRepositoryProvider)
                                                .revokeInvite(inv.id);
                                            ref.invalidate(_invitesProvider);
                                          },
                                        )
                                      : null,
                                ),
                              )),
                        ],
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    String role = 'staff';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Invite member',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: kRoles
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setState(() => role = v ?? 'staff'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final shopId = ref.read(currentShopIdProvider);
                    if (shopId == null) return;
                    try {
                      await ref.read(membersRepositoryProvider).invite(
                          shopId, emailCtrl.text.trim(), role);
                      ref.invalidate(_invitesProvider);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        showSnack(context, 'Invite sent');
                      }
                    } catch (e) {
                      if (ctx.mounted) showSnack(ctx, '$e', error: true);
                    }
                  },
                  child: const Text('Send invite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleMenu extends StatelessWidget {
  const _RoleMenu({
    required this.current,
    required this.onChange,
    required this.onRemove,
  });
  final String current;
  final ValueChanged<String> onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      child: Chip(
        label: Text(current.toUpperCase()),
        avatar: const Icon(Icons.arrow_drop_down, size: 18),
      ),
      onSelected: (v) => v == '__remove' ? onRemove() : onChange(v),
      itemBuilder: (_) => [
        ...kRoles.map((r) =>
            PopupMenuItem(value: r, child: Text('Set ${r.toUpperCase()}'))),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: '__remove',
            child: Text('Remove', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}
