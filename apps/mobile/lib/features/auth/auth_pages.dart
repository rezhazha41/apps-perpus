import 'dart:async';

import 'package:flutter/material.dart';
import 'package:perpus_ui_kit/perpus_ui_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/supabase_config.dart';
import '../server/server_shell.dart';

String authErrorMessage(String raw) {
  final message = raw.toLowerCase();
  if (message.contains('timeout') ||
      message.contains('deadline exceeded') ||
      message.contains('request_timeout') ||
      message.contains('504')) {
    return 'Respons server terlambat, jadi hasil pendaftaran belum dapat dipastikan. Periksa email konfirmasi sebelum mencoba kembali atau hubungi pengurus.';
  }
  if (message.contains('not registered') ||
      message.contains('not found') ||
      message.contains('tidak dapat diproses')) {
    return 'Data siswa belum terdaftar atau tidak cocok. Minta pengurus memeriksa data NIS/NISN.';
  }
  if (message.contains('invalid login') ||
      message.contains('invalid credentials')) {
    return 'Email atau kata sandi belum benar.';
  }
  if (message.contains('email not confirmed')) {
    return 'Konfirmasi email dari kotak masuk sebelum masuk.';
  }
  if (message.contains('already registered') ||
      message.contains('already been registered')) {
    return 'Email ini sudah memiliki akun. Coba masuk.';
  }
  if (message.contains('password')) {
    return 'Kata sandi harus terdiri dari minimal 8 karakter.';
  }
  if (message.contains('socket') ||
      message.contains('handshake') ||
      message.contains('certificate')) {
    return 'Koneksi aman ke server gagal. Periksa jaringan Wi-Fi dan sertifikat HTTPS.';
  }
  return 'Autentikasi belum berhasil. Coba lagi atau hubungi pengurus perpustakaan.';
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.expectedRole,
    this.startWithSignup = false,
    this.startWithStaffInvite = false,
  });
  final String expectedRole;
  final bool startWithSignup;
  final bool startWithStaffInvite;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _identity = TextEditingController();
  final _contact = TextEditingController();
  final _staffInvite = TextEditingController();
  late bool _signup = widget.expectedRole == 'member'
      ? widget.startWithSignup
      : widget.startWithStaffInvite;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _notice;
  String? _error;
  String _identityKind = 'nis';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _identity.dispose();
    _contact.dispose();
    _staffInvite.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _notice = null;
      _error = null;
    });
    try {
      if (_signup) {
        final response = await _client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: SupabaseConfig.authCallback,
          data: {
            'account_kind': widget.expectedRole == 'admin' ? 'staff' : 'member',
            if (widget.expectedRole == 'admin')
              'staff_invite_token': _staffInvite.text.trim(),
            if (widget.expectedRole == 'member') ...{
              'identity_kind': _identityKind,
              'identity_number': _identity.text.trim(),
            },
            if (_contact.text.trim().isNotEmpty)
              'contact': _contact.text.trim(),
          },
        );
        if (!mounted) return;
        if (response.session == null) {
          setState(() {
            _signup = false;
            _notice = 'Jika pendaftaran memenuhi syarat, tautan konfirmasi akan dikirim ke email. Setelah konfirmasi, tunggu aktivasi admin lalu masuk di sini.';
          });
        } else {
          Navigator.of(context).pop();
        }
      } else {
        await _client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        final profile = await _client
            .from('profiles')
            .select('role')
            .eq('id', _client.auth.currentUser!.id)
            .maybeSingle();
        if (profile?['role'] != widget.expectedRole) {
          await _client.auth.signOut();
          if (mounted) {
            setState(
              () => _error = widget.expectedRole == 'admin'
                  ? 'Akun ini bukan akun pengurus. Pilih jalur masuk anggota.'
                  : 'Akun ini bukan akun anggota. Pilih jalur masuk pengurus.',
            );
          }
          return;
        }
        if (mounted) Navigator.of(context).pop();
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = _authMessage(exception.message));
    } on FormatException catch (exception) {
      if (mounted) setState(() => _error = _authMessage(exception.message));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tidak bisa terhubung ke server. Periksa internet dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _notice = null;
        _error = 'Masukkan alamat email yang valid terlebih dahulu.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _notice = null;
      _error = null;
    });
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.passwordRecoveryCallback,
      );
      if (mounted) {
        setState(() {
          _notice = 'Jika akun dengan email itu tersedia, tautan reset akan dikirim. Buka tautan dari perangkat ini untuk mengganti kata sandi.';
        });
      }
    } on AuthException catch (exception) {
      if (mounted) {
        setState(() => _error = _passwordResetError(exception.message));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Permintaan reset belum terkirim. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _passwordResetError(String raw) {
    final message = raw.toLowerCase();
    if (message.contains('redirect') || message.contains('uri')) {
      return 'Callback pemulihan ditolak server. Periksa allow-list redirect Supabase.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Terlalu banyak permintaan reset. Tunggu sebentar sebelum mencoba lagi.';
    }
    if (message.contains('smtp') ||
        message.contains('sending recovery') ||
        message.contains('email delivery')) {
      return 'Server belum berhasil mengirim email reset. Minta pengurus memeriksa SMTP.';
    }
    if (raw.trim().isEmpty) {
      return 'Permintaan reset ditolak server tanpa keterangan. Coba lagi dan periksa koneksi.';
    }
    return 'Permintaan reset gagal: ${raw.trim()}';
  }

  String _authMessage(String raw) {
    return authErrorMessage(raw);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _signup
            ? widget.expectedRole == 'admin'
                  ? 'Aktivasi undangan pengurus'
                  : 'Daftar anggota'
            : widget.expectedRole == 'admin'
            ? 'Masuk pengurus'
            : 'Masuk anggota',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Row(
              children: [
                Icon(Icons.local_library_rounded, size: 28),
                SizedBox(width: 10),
                Text(
                  'perpus.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _signup
                  ? widget.expectedRole == 'admin'
                        ? 'Aktifkan akun melalui undangan yang dibuat admin.'
                        : 'Daftar dengan identitas siswa.'
                  : 'Senang melihatmu kembali.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _signup
                  ? widget.expectedRole == 'admin'
                        ? 'Kode hanya berlaku satu kali, untuk email yang diundang, dan kedaluwarsa dalam 48 jam.'
                        : 'Gunakan NIS atau NISN yang sudah dimasukkan pengurus perpustakaan.'
                  : 'Masuk memakai email dan kata sandi akun ${widget.expectedRole == 'admin' ? 'pengurus' : 'anggota'}.',
              style: const TextStyle(color: PerpusColors.muted),
            ),
            const SizedBox(height: 22),
            if (_notice != null) ...[
              _messageCard(_notice!, Icons.mark_email_read_outlined),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              _messageCard(_error!, Icons.error_outline),
              const SizedBox(height: 16),
            ],
            Form(
              key: _form,
              child: Column(
                children: [
                  if (_signup && widget.expectedRole == 'admin') ...[
                    TextFormField(
                      controller: _staffInvite,
                      validator: _required,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Kode undangan pengurus',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_signup && widget.expectedRole == 'member') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _identityKind,
                      decoration: const InputDecoration(
                        labelText: 'Jenis identitas',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'nis', child: Text('NIS')),
                        DropdownMenuItem(value: 'nisn', child: Text('NISN')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _identityKind = value ?? 'nis'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _identity,
                      validator: _required,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _identityKind.toUpperCase(),
                        hintText: 'Masukkan nomor $_identityKind',
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email wajib diisi.';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Periksa format email.';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'nama@email.com',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kata sandi wajib diisi.';
                      }
                      if (value.length < 8) {
                        return 'Gunakan minimal 8 karakter.';
                      }
                      return null;
                    },
                    obscureText: _obscurePassword,
                    textInputAction: _signup
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: _signup
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Kata sandi',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Tampilkan kata sandi'
                            : 'Sembunyikan kata sandi',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_signup) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contact,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Kontak (opsional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                _busy
                    ? 'Menghubungkan…'
                    : _signup
                    ? 'Kirim pendaftaran'
                    : 'Masuk',
              ),
            ),
            if (!_signup)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                children: [
                  if (widget.expectedRole == 'member')
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const AccountAccessRecoveryPage(),
                              ),
                            ),
                      child: const Text('Tidak bisa mengakses email?'),
                    )
                  else
                    const SizedBox.shrink(),
                  TextButton(
                    onPressed: _busy ? null : _requestPasswordReset,
                    child: const Text('Lupa kata sandi?'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (widget.expectedRole == 'member' ||
                widget.expectedRole == 'admin')
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _signup = !_signup;
                        _notice = null;
                        _error = null;
                      }),
                child: Text(
                  widget.expectedRole == 'admin'
                      ? _signup
                            ? 'Kembali ke masuk pengurus'
                            : 'Punya undangan staf? Aktivasi di sini'
                      : _signup
                      ? 'Sudah punya akun? Masuk'
                      : 'Belum punya akun? Daftar sebagai anggota',
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _signup
                  ? widget.expectedRole == 'admin'
                        ? 'Akun staf menunggu konfirmasi email dan persetujuan admin.'
                        : 'Akun anggota perlu email terkonfirmasi dan persetujuan pengurus sebelum mendapat akses.'
                  : widget.expectedRole == 'admin'
                  ? 'Akun pengurus hanya dibuat melalui undangan atau Supabase Studio.'
                  : 'Masuk menggunakan akun anggota yang sudah aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: PerpusColors.muted),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _messageCard(String text, IconData icon) => PaperCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

typedef RedeemAccountRecovery = Future<void> Function({
  required String challengeId,
  required String code,
  required String password,
});

class AccountAccessRecoveryPage extends StatefulWidget {
  const AccountAccessRecoveryPage({super.key, this.redeem});

  final RedeemAccountRecovery? redeem;

  @override
  State<AccountAccessRecoveryPage> createState() =>
      _AccountAccessRecoveryPageState();
}

class _AccountAccessRecoveryPageState extends State<AccountAccessRecoveryPage> {
  final _form = GlobalKey<FormState>();
  final _challengeId = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _notice;
  String? _error;

  @override
  void dispose() {
    _challengeId.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

  Future<void> _redeemWithServer({
    required String challengeId,
    required String code,
    required String password,
  }) async {
    await Supabase.instance.client.functions.invoke(
      'account-recovery',
      body: {
        'action': 'redeem',
        'challenge_id': challengeId,
        'code': code,
        'password': password,
      },
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Kata sandi belum sama.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _notice = null;
      _error = null;
    });
    try {
      final code = _code.text.toUpperCase().replaceAll(
        RegExp(r'[^A-Z0-9]'),
        '',
      );
      await (widget.redeem ?? _redeemWithServer)(
        challengeId: _challengeId.text.trim(),
        code: code,
        password: _password.text,
      );
      if (mounted) {
        setState(() => _notice = 'Akses akun berhasil dipulihkan.');
      }
    } on FunctionException catch (error) {
      if (mounted) {
        final details = error.details;
        setState(
          () => _error = details is Map && details['message'] is String
              ? details['message'] as String
              : 'Kode pemulihan salah, kedaluwarsa, atau sudah digunakan.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Pemulihan belum berhasil. Periksa kode atau minta pengurus membuat kode baru.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pulihkan akses anggota')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PaperCard(
              child: Text(
                'Datang ke pengurus dengan kartu pelajar atau identitas sekolah. Setelah identitasmu diperiksa, pengurus akan memberikan ID dan kode yang berlaku 15 menit.',
              ),
            ),
            const SizedBox(height: 18),
            if (_notice != null) ...[
              Text(_notice!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _challengeId,
                    validator: _required,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'ID pemulihan',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    validator: (value) {
                      final normalized = value?.toUpperCase().replaceAll(
                        RegExp(r'[^A-Z0-9]'),
                        '',
                      );
                      return normalized?.length == 12
                          ? null
                          : 'Masukkan kode 12 karakter dari pengurus.';
                    },
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kode dari pengurus',
                      hintText: 'ABCD-EFGH-IJKL',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    validator: (value) => value == null || value.length < 8
                        ? 'Gunakan minimal 8 karakter.'
                        : null,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi baru',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Tampilkan kata sandi'
                            : 'Sembunyikan kata sandi',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmation,
                    validator: _required,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi kata sandi baru',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_outlined),
              label: const Text('Pulihkan akun'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.session});
  final Session session;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Future<Map<String, dynamic>?>? _profile;
  bool _resubmitting = false;
  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() => Supabase.instance.client
      .from('profiles')
      .select('role,status,rejection_reason')
      .eq('id', widget.session.user.id)
      .maybeSingle();

  Future<void> _signOut() => Supabase.instance.client.auth.signOut();

  Future<void> _resubmit() async {
    setState(() => _resubmitting = true);
    try {
      await Supabase.instance.client.rpc('resubmit_member_application');
      final next = _loadProfile();
      if (mounted) setState(() => _profile = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengajuan ulang belum berhasil. Identitas mungkin sedang dipakai pengajuan lain.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Akun Perpus'),
      actions: [
        IconButton(
          tooltip: 'Keluar',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.account_circle_outlined,
          size: 72,
          color: PerpusColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          widget.session.user.email ?? 'Akun Perpus',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 22),
        FutureBuilder<Map<String, dynamic>?>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _status(
                'Profil belum dapat dimuat. Periksa koneksi dan aturan akses database.',
                Icons.cloud_off_outlined,
                action: TextButton(
                  onPressed: () {
                    final next = _loadProfile();
                    setState(() {
                      _profile = next;
                    });
                  },
                  child: const Text('Coba lagi'),
                ),
              );
            }
            final profile = snapshot.data;
            if (profile == null) {
              return _status(
                'Profil akun tidak ditemukan. Hubungi pengurus perpustakaan.',
                Icons.person_search_outlined,
              );
            }
            final role = profile['role'] as String? ?? 'member';
            final status = profile['status'] as String? ?? 'pending';
            final rejection = profile['rejection_reason'] as String?;
            if (status == 'pending') {
              return _status(
                'Email terkonfirmasi. Pendaftaranmu sedang menunggu persetujuan pengurus.',
                Icons.hourglass_top_rounded,
              );
            }
            if (status == 'rejected') {
              return _status(
                'Pendaftaran belum disetujui.${rejection == null ? '' : ' Alasan: $rejection'}',
                Icons.info_outline,
                detail: 'Perbaiki data yang diminta, lalu gunakan akun yang sama untuk mengajukan kembali.',
                action: FilledButton.icon(
                  onPressed: _resubmitting ? null : _resubmit,
                  icon: const Icon(Icons.replay_outlined),
                  label: Text(
                    _resubmitting
                        ? 'Mengajukan…'
                        : 'Ajukan pendaftaran kembali',
                  ),
                ),
              );
            }
            if (status != 'active') {
              return _status(
                'Akun sedang tidak aktif. Hubungi pengurus untuk bantuan.',
                Icons.lock_outline,
              );
            }
            return _status(
              role == 'admin' ? 'Akun pengurus aktif.' : 'Akun anggota aktif.',
              role == 'admin'
                  ? Icons.admin_panel_settings_outlined
                  : Icons.verified_user_outlined,
              detail: 'Login Supabase berhasil. Katalog dan data peminjaman akan muncul setelah layanan server siap.',
            );
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Supabase.instance.client.auth.refreshSession(),
          icon: const Icon(Icons.refresh),
          label: const Text('Perbarui status akun'),
        ),
      ],
    ),
  );

  Widget _status(
    String text,
    IconData icon, {
    String? detail,
    Widget? action,
  }) => PaperCard(
    child: Column(
      children: [
        Icon(icon, size: 34, color: PerpusColors.primary),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PerpusColors.muted),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 8), action],
      ],
    ),
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.onContinue,
    this.updatePassword,
  });
  final VoidCallback onContinue;
  final Future<void> Function(String password)? updatePassword;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _busy = false;
  bool _updated = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updatePassword = widget.updatePassword;
      if (updatePassword == null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _password.text),
        );
      } else {
        await updatePassword(_password.text);
      }
      if (mounted) setState(() => _updated = true);
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Kata sandi belum berhasil diperbarui. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atur kata sandi baru')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          shrinkWrap: true,
          children: [
            Icon(
              _updated ? Icons.verified_outlined : Icons.lock_reset_outlined,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _updated
                  ? 'Kata sandi berhasil diperbarui.'
                  : 'Masukkan kata sandi baru untuk akunmu.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_updated)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: FilledButton(
                  onPressed: widget.onContinue,
                  child: const Text('Lanjutkan ke Perpus'),
                ),
              )
            else ...[
              const SizedBox(height: 24),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi baru',
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Sembunyikan kata sandi'
                              : 'Tampilkan kata sandi',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? 'Gunakan minimal 8 karakter.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: !_showConfirmation,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Ulangi kata sandi baru',
                        suffixIcon: IconButton(
                          tooltip: _showConfirmation
                              ? 'Sembunyikan konfirmasi kata sandi'
                              : 'Tampilkan konfirmasi kata sandi',
                          onPressed: () => setState(
                            () => _showConfirmation = !_showConfirmation,
                          ),
                          icon: Icon(
                            _showConfirmation
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value != _password.text
                          ? 'Kata sandi belum sama.'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _updatePassword,
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Text('Simpan kata sandi'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SessionRouter extends StatefulWidget {
  const SessionRouter({
    super.key,
    required this.signedOutBuilder,
    this.initialPasswordRecovery = false,
  });
  final WidgetBuilder signedOutBuilder;
  final bool initialPasswordRecovery;

  @override
  State<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends State<SessionRouter> {
  StreamSubscription<AuthState>? _subscription;
  late bool _passwordRecovery = widget.initialPasswordRecovery;

  @override
  void initState() {
    super.initState();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _passwordRecovery = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        });
      } else if (state.event == AuthChangeEvent.signedOut) {
        setState(() => _passwordRecovery = false);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    initialData: AuthState(
      AuthChangeEvent.initialSession,
      Supabase.instance.client.auth.currentSession,
    ),
    builder: (context, snapshot) {
      final session =
          snapshot.data?.session ??
          Supabase.instance.client.auth.currentSession;
      if (_passwordRecovery) {
        return PasswordRecoveryPage(
          key: ValueKey('password-recovery-${session?.user.id ?? 'pending'}'),
          onContinue: () => setState(() => _passwordRecovery = false),
        );
      }
      if (session == null) return widget.signedOutBuilder(context);
      return _ActiveProfileRouter(
        key: ValueKey(session.user.id),
        session: session,
      );
    },
  );
}

class _ActiveProfileRouter extends StatefulWidget {
  const _ActiveProfileRouter({super.key, required this.session});
  final Session session;

  @override
  State<_ActiveProfileRouter> createState() => _ActiveProfileRouterState();
}

class _ActiveProfileRouterState extends State<_ActiveProfileRouter> {
  late Future<Map<String, dynamic>?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() => Supabase.instance.client
      .from('profiles')
      .select('role,status')
      .eq('id', widget.session.user.id)
      .maybeSingle();

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = snapshot.data;
      if (snapshot.hasError ||
          profile == null ||
          profile['status'] != 'active') {
        return AccountPage(session: widget.session);
      }
      return ServerShell(
        user: widget.session.user,
        isAdmin: profile['role'] == 'admin',
      );
    },
  );
}
