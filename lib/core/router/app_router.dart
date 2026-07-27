import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customer_form_screen.dart';
import '../../features/dashboard/presentation/home_gate.dart';
import '../../features/dashboard/presentation/home_shell.dart';
import '../../features/khata/presentation/khata_detail_screen.dart';
import '../../features/khata/presentation/khata_entry_screen.dart';
import '../../features/members/presentation/members_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/receipts/presentation/receipt_detail_screen.dart';
import '../../features/receipts/presentation/receipt_form_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shops/presentation/shop_form_screen.dart';
import '../../features/shops/presentation/shop_selection_screen.dart';
import 'refresh_stream.dart';

/// Central router with auth + email-verification redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable:
        GoRouterRefreshStream(authRepo.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = authRepo.currentSession != null;
      final verified = authRepo.isEmailVerified;
      final loc = state.matchedLocation;

      const authRoutes = {'/login', '/signup', '/forgot'};
      final onAuthRoute = authRoutes.contains(loc);
      final onVerify = loc == '/verify';
      final onReset = loc == '/reset-password';

      // Password recovery deep link is always allowed through.
      if (onReset) return null;

      if (!loggedIn) {
        return onAuthRoute ? null : '/login';
      }
      // Logged in but email not confirmed.
      if (!verified) {
        return onVerify ? null : '/verify';
      }
      // Logged in & verified — keep them out of auth/verify screens.
      if (onAuthRoute || onVerify) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
          path: '/reset-password',
          builder: (_, __) => const ResetPasswordScreen()),

      // Shop selection & shop CRUD.
      GoRoute(
          path: '/shops', builder: (_, __) => const ShopSelectionScreen()),
      GoRoute(
          path: '/shops/new', builder: (_, __) => const ShopFormScreen()),
      GoRoute(
        path: '/shops/edit',
        builder: (_, state) =>
            ShopFormScreen(existing: state.extra as dynamic),
      ),

      // Home gate decides between shop-selection and the main shell.
      GoRoute(path: '/', builder: (_, __) => const HomeGate()),

      // Main tabbed shell (dashboard / products / receipts / khata / more).
      GoRoute(
        path: '/home',
        builder: (_, state) =>
            HomeShell(initialTab: int.tryParse(
                    state.uri.queryParameters['tab'] ?? '0') ??
                0),
      ),

      // Members.
      GoRoute(path: '/members', builder: (_, __) => const MembersScreen()),

      // Settings.
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

      // Reports & global search.
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/search', builder: (_, __) => const GlobalSearchScreen()),

      // Products.
      GoRoute(
        path: '/products/new',
        builder: (_, __) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/products/:id/edit',
        builder: (_, state) =>
            ProductFormScreen(productId: state.pathParameters['id']),
      ),

      // Receipts.
      GoRoute(
        path: '/receipts/new',
        builder: (_, __) => const ReceiptFormScreen(),
      ),
      GoRoute(
        path: '/receipts/:id',
        builder: (_, state) =>
            ReceiptDetailScreen(receiptId: state.pathParameters['id']!),
      ),

      // Customers.
      GoRoute(
        path: '/customers/new',
        builder: (_, __) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (_, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (_, state) =>
            CustomerFormScreen(customerId: state.pathParameters['id']),
      ),

      // Khata add transaction (customer id via query).
      GoRoute(
        path: '/khata/new',
        builder: (_, state) => KhataEntryScreen(
          customerId: state.uri.queryParameters['customer']!,
        ),
      ),

      // Dedicated per-customer khata ledger page.
      GoRoute(
        path: '/khata/customer/:id',
        builder: (_, state) =>
            KhataDetailScreen(customerId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
