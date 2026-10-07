import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/server_shell.dart';

void main() {
  testWidgets('text dialog closes without using a disposed controller', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showTextDialog(context, 'Judul', 'Keterangan');
            },
            child: const Text('Buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Buku hilang');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(result, 'Buku hilang');
    expect(tester.takeException(), isNull);
  });
}
