/// Project URL and publishable key are client credentials protected by RLS.
/// Override either value per build without committing environment files.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sup.tunneladguard.xyz',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_d25hi78DVxIYriygEFC5ae_LDdA-VdW',
  );
  static const authCallback = 'id.perpus.perpus-mobile://login-callback';
  static const passwordRecoveryCallback =
      'id.perpus.perpus-mobile://reset-password';

  static bool isPasswordRecoveryCallback(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'id.perpus.perpus-mobile' ||
        uri.host != 'reset-password') {
      return false;
    }
    try {
      return uri.queryParameters['type'] == 'recovery' ||
          uri.queryParameters.containsKey('code') ||
          Uri.splitQueryString(uri.fragment)['type'] == 'recovery';
    } on FormatException {
      return false;
    }
  }
}
