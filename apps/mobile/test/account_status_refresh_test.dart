import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/auth/auth_pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('refresh status reloads profile and asks router to refresh', (
    tester,
  ) async {
    var profileLoads = 0;
    var routerRefreshes = 0;

    Future<Map<String, dynamic>?> loadProfile() async {
      profileLoads++;
      return {
        'role': 'member',
        'status': profileLoads == 1 ? 'pending' : 'active',
      };
    }

    final session = Session.fromJson({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {'id': 'member-1', 'email': 'member@example.test'},
    })!;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountPage(
          session: session,
          profileLoader: loadProfile,
          onRefresh: () => routerRefreshes++,
          refreshSession: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('menunggu persetujuan'), findsOneWidget);

    await tester.tap(find.text('Perbarui status akun'));
    await tester.pumpAndSettle();

    expect(profileLoads, 2);
    expect(routerRefreshes, 1);
    expect(find.text('Akun anggota aktif.'), findsOneWidget);
  });
}
