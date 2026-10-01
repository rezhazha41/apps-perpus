import 'package:flutter/material.dart';
import 'package:perpus_ui_kit/perpus_ui_kit.dart';

import '../features/auth/auth_pages.dart';
import 'session_idle_timeout.dart';

class PerpusApp extends StatelessWidget {
  const PerpusApp({super.key, this.initialPasswordRecovery = false});
  final bool initialPasswordRecovery;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Perpus',
    debugShowCheckedModeBanner: false,
    theme: perpusTheme(),
    builder: (context, child) => Listener(
      onPointerDown: (_) => SessionIdleTimeout.recordActivity(),
      child: child ?? const SizedBox.shrink(),
    ),
    home: SessionRouter(
      initialPasswordRecovery: initialPasswordRecovery,
      signedOutBuilder: (_) => const WelcomePage(),
    ),
  );
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  void openAuth({required String role, bool signup = false}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AuthPage(
            expectedRole: role,
            startWithSignup: signup,
            startWithStaffInvite: false,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.local_library_rounded, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'perpus.',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              PaperCard(
                dark: true,
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RUANG UNTUK BERTUMBUH',
                      style: TextStyle(
                        color: PerpusColors.accent,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Cerita baru.\nWawasan baru.\nMulai dari buku.',
                      style: TextStyle(
                        fontSize: 37,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        color: PerpusColors.surface,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        spine('TEMUKAN', 124, PerpusColors.accent),
                        const SizedBox(width: 8),
                        spine('BACA', 150, PerpusColors.surface),
                        const SizedBox(width: 8),
                        spine('BERTUMBUH', 108, const Color(0xFFB4C0B7)),
                        const Spacer(),
                        const Icon(
                          Icons.north_east,
                          size: 36,
                          color: PerpusColors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Perpustakaan dalam genggaman.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Temukan bacaan, pantau pinjaman, dan kelola perpustakaan dari satu tempat.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => openAuth(role: 'member'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Masuk sebagai anggota'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openAuth(role: 'member', signup: true),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Daftar anggota'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openAuth(role: 'admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Masuk sebagai pengurus'),
              ),
              const SizedBox(height: 12),
              const Text(
                'KONEKSI SERVER • DATA DEMO TERPISAH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget spine(String label, double height, Color color) => Container(
    width: 48,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(5),
        topRight: Radius.circular(10),
      ),
    ),
    child: Center(
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    ),
  );
}
