import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/server_shell.dart';

void main() {
  testWidgets('evidence type unlocks camera but photo is still required', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MemberLoanRequestPage(
          copy: {
            'id': 'test-copy',
            'code': 'TEST-01',
            'books': {'id': 'test-book', 'title': 'Buku uji'},
          },
        ),
      ),
    );
    final camera = find.widgetWithText(
      OutlinedButton,
      'Pilih jenis bukti terlebih dahulu',
    );
    expect(tester.widget<OutlinedButton>(camera).onPressed, isNull);
    await tester.tap(find.text('Selfie'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Ambil foto bukti'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Ajukan pinjaman'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Pinjam sekarang'), findsNothing);
  });
}
