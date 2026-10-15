import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/app/date_formatters.dart';
import 'package:perpus_mobile/app/form_validators.dart';
import 'package:perpus_mobile/app/perpus_app.dart';
import 'package:perpus_mobile/app/supabase_config.dart';
import 'package:perpus_mobile/features/auth/auth_pages.dart';
import 'package:perpus_mobile/features/demo/demo_shell.dart';
import 'package:perpus_data_access/perpus_data_access.dart';
import 'package:perpus_ui_kit/perpus_ui_kit.dart';

void main() {
  test('recovery callback detection handles query and fragment links', () {
    expect(
      SupabaseConfig.isPasswordRecoveryCallback(
        Uri.parse(
          'id.perpus.perpus-mobile://reset-password?type=recovery&code=x',
        ),
      ),
      isTrue,
    );
    expect(
      SupabaseConfig.isPasswordRecoveryCallback(
        Uri.parse(
          'id.perpus.perpus-mobile://reset-password#access_token=x&type=recovery',
        ),
      ),
      isTrue,
    );
    expect(
      SupabaseConfig.isPasswordRecoveryCallback(
        Uri.parse('id.perpus.perpus-mobile://reset-password?code=x'),
      ),
      isTrue,
    );
    expect(
      SupabaseConfig.isPasswordRecoveryCallback(
        Uri.parse(
          'id.perpus.perpus-mobile://login-callback?code=x&type=signup',
        ),
      ),
      isFalse,
    );
    expect(
      SupabaseConfig.isPasswordRecoveryCallback(
        Uri.parse('https://example.com?type=recovery'),
      ),
      isFalse,
    );
  });

  test(
    'signup timeout is ambiguous and does not ask for an automatic retry',
    () {
      final message = authErrorMessage('request_timeout 504');

      expect(
        message,
        'Respons server terlambat, jadi hasil pendaftaran belum dapat dipastikan. Periksa email konfirmasi sebelum mencoba kembali atau hubungi pengurus.',
      );
      expect(message, contains('belum dapat dipastikan'));
      expect(message, isNot(contains('belum tercatat')));
      expect(message.toLowerCase(), isNot(contains('coba lagi')));
    },
  );

  test('required field validator preserves empty and filled outputs', () {
    expect(requiredFieldValidator(null), 'Bagian ini wajib diisi.');
    expect(requiredFieldValidator('  '), 'Bagian ini wajib diisi.');
    expect(requiredFieldValidator('Nama'), isNull);
    expect(requiredFieldValidator('', message: 'Wajib diisi.'), 'Wajib diisi.');
  });

  test('server date formatters preserve current date and time output', () {
    const localDateTime = '2026-01-02T03:04:05';

    expect(formatServerDate(localDateTime), '02/01/2026');
    expect(formatServerDateTime(localDateTime), '02/01/2026 pukul 03:04');
    expect(formatServerDate('not-a-date'), '—');
    expect(formatServerDateTime(null), '—');
  });

  testWidgets('member signup stays open and asks for student identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: perpusTheme(),
        home: const AuthPage(expectedRole: 'member', startWithSignup: true),
      ),
    );
    expect(find.text('Daftar anggota'), findsOneWidget);
    expect(find.text('Jenis identitas'), findsOneWidget);
    expect(find.text('Kode undangan pengurus'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member login offers assisted recovery without email access', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: perpusTheme(),
        home: const AuthPage(expectedRole: 'member'),
      ),
    );

    expect(find.text('Tidak bisa mengakses email?'), findsOneWidget);
    await tester.tap(find.text('Tidak bisa mengakses email?'));
    await tester.pumpAndSettle();
    expect(find.text('Pulihkan akses anggota'), findsOneWidget);
    expect(find.text('ID pemulihan'), findsOneWidget);
    expect(find.text('Kode dari pengurus'), findsOneWidget);
  });

  testWidgets('assisted recovery validates and submits a one-time code', (
    tester,
  ) async {
    Map<String, String>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: perpusTheme(),
        home: AccountAccessRecoveryPage(
          redeem:
              ({required challengeId, required code, required password}) async {
                submitted = {
                  'challengeId': challengeId,
                  'code': code,
                  'password': password,
                };
              },
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'challenge-123');
    await tester.enterText(fields.at(1), 'ABCD-EFGH-IJKL');
    await tester.enterText(fields.at(2), 'kata-sandi-baru');
    await tester.enterText(fields.at(3), 'kata-sandi-baru');
    await tester.tap(find.text('Pulihkan akun'));
    await tester.pumpAndSettle();

    expect(submitted?['challengeId'], 'challenge-123');
    expect(submitted?['code'], 'ABCDEFGHIJKL');
    expect(submitted?['password'], 'kata-sandi-baru');
    expect(find.text('Akses akun berhasil dipulihkan.'), findsOneWidget);
  });

  testWidgets('admin login offers invite-only staff activation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: perpusTheme(),
        home: const AuthPage(expectedRole: 'admin'),
      ),
    );
    expect(find.text('Masuk pengurus'), findsOneWidget);
    expect(find.text('Belum punya akun? Daftar sebagai anggota'), findsNothing);
    await tester.tap(find.text('Punya undangan staf? Aktivasi di sini'));
    await tester.pumpAndSettle();
    expect(find.text('Aktivasi undangan pengurus'), findsOneWidget);
    expect(find.text('Kode undangan pengurus'), findsOneWidget);
    expect(find.text('Jenis identitas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password recovery validates and saves a matching password', (
    tester,
  ) async {
    String? savedPassword;
    await tester.pumpWidget(
      MaterialApp(
        theme: perpusTheme(),
        home: PasswordRecoveryPage(
          onContinue: () {},
          updatePassword: (password) async {
            savedPassword = password;
          },
        ),
      ),
    );
    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();
    expect(find.byTooltip('Sembunyikan kata sandi'), findsOneWidget);
    await tester.tap(find.byTooltip('Tampilkan konfirmasi kata sandi'));
    await tester.pump();
    expect(find.byTooltip('Sembunyikan konfirmasi kata sandi'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pumpAndSettle();
    expect(find.text('Gunakan minimal 8 karakter.'), findsOneWidget);
    expect(savedPassword, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'password-baru');
    await tester.enterText(find.byType(TextFormField).at(1), 'beda-password');
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pumpAndSettle();
    expect(find.text('Kata sandi belum sama.'), findsOneWidget);
    expect(savedPassword, isNull);

    await tester.enterText(find.byType(TextFormField).at(1), 'password-baru');
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pumpAndSettle();
    expect(savedPassword, 'password-baru');
    expect(find.text('Kata sandi berhasil diperbarui.'), findsOneWidget);
  });

  testWidgets('main pages support narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: perpusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: DemoShell(library: DemoLibrary(), admin: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Katalog', 'Pinjaman', 'Profil']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('welcome page exposes member registration and separate logins', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: perpusTheme(), home: const WelcomePage()),
    );
    await tester.scrollUntilVisible(find.text('Masuk sebagai anggota'), 250);
    expect(find.text('Masuk sebagai anggota'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Daftar anggota'), 180);
    expect(find.text('Daftar anggota'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Masuk sebagai pengurus'), 180);
    expect(find.text('Masuk sebagai pengurus'), findsOneWidget);
    expect(find.textContaining('Jelajahi demo'), findsNothing);
    await tester.tap(find.text('Daftar anggota'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar anggota'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk sebagai pengurus'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk pengurus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
