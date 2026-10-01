import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

import 'app/perpus_app.dart';
import 'app/session_idle_timeout.dart';
import 'app/supabase_config.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Uri? initialLink;
  try {
    initialLink = await AppLinks().getInitialLink();
  } catch (_) {
    // Supabase's own link observer remains responsible for exchanging links.
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  await SessionIdleTimeout.initialize();
  runApp(
    PerpusApp(
      initialPasswordRecovery: SupabaseConfig.isPasswordRecoveryCallback(
        initialLink,
      ),
    ),
  );
}
