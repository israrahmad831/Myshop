import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';

/// Shown after sign-up while the email is unconfirmed. Lets the user resend the
/// verification email and refresh once they've clicked the link.
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {/* still unverified */}
    ref.invalidate(authStateChangesProvider);
    if (context.mounted) {
      showSnack(context,
          ref.read(isEmailVerifiedProvider) ? 'Verified!' : 'Not verified yet');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify email'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(authRepositoryProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Verify your email',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification link to\n$email.\n'
                  'Open it, then come back and tap "I have verified".',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => _refresh(context, ref),
                  child: const Text('I have verified'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .resendVerification(email);
                          if (context.mounted && ok) {
                            showSnack(context, 'Verification email resent');
                          }
                        },
                  child: const Text('Resend email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
