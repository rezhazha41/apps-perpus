import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/server_shell.dart';

void main() {
  testWidgets('successful loan request redirects to pending loans', (
    tester,
  ) async {
    var redirected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberQrScanPage(
          onLoanRequestSubmitted: () => redirected = true,
          initialCopy: const {
            'id': 'test-copy',
            'code': 'TEST-01',
            'status': 'available',
            'books': {'id': 'test-book', 'title': 'Buku uji'},
          },
        ),
      ),
    );

    await tester.tap(find.text('Ajukan pinjaman'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberLoanRequestPage), findsOneWidget);

    tester
        .widget<MemberLoanRequestPage>(find.byType(MemberLoanRequestPage))
        .onSubmitted!();
    await tester.pumpAndSettle();

    expect(redirected, isTrue);
    expect(find.byType(MemberLoanRequestPage), findsNothing);
  });
}
