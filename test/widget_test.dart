// Basic smoke test. The full app requires Supabase configuration (via
// --dart-define), so here we just verify the root widget builds without
// throwing when configuration is absent (it shows the "not configured" screen).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shop_manager/app.dart';

void main() {
  testWidgets('App builds without configuration', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShopManagerApp()));
    expect(find.textContaining('Supabase is not configured'), findsOneWidget);
  });
}
