const ACTIVE_SERVER_HOSTS = new Set(['sup.tunneladguard.xyz']);
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1']);

function required(env, name) {
  const value = env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

export function loadIntegrationConfig(env = process.env) {
  if (env.PERPUS_TEST_CONFIRM !== 'isolated-disposable') {
    throw new Error(
      'Refusing to run. Set PERPUS_TEST_CONFIRM=isolated-disposable only for a disposable test stack.',
    );
  }

  const rawUrl = required(env, 'PERPUS_TEST_SUPABASE_URL');
  let url;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new Error('PERPUS_TEST_SUPABASE_URL must be a valid HTTP(S) URL.');
  }
  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('PERPUS_TEST_SUPABASE_URL must use HTTP or HTTPS.');
  }
  if (url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('PERPUS_TEST_SUPABASE_URL must contain only scheme, host, and optional port.');
  }
  if (ACTIVE_SERVER_HOSTS.has(url.hostname.toLowerCase())) {
    throw new Error('Runner refuses the active Perpus server. Use a disposable Supabase stack.');
  }
  if (!LOCAL_HOSTS.has(url.hostname.toLowerCase()) && env.PERPUS_TEST_REMOTE_ISOLATED !== 'yes') {
    throw new Error(
      'Remote stacks additionally require PERPUS_TEST_REMOTE_ISOLATED=yes after isolation is verified.',
    );
  }

  const anonKey = required(env, 'PERPUS_TEST_ANON_KEY');
  const serviceRoleKey = required(env, 'PERPUS_TEST_SERVICE_ROLE_KEY');
  if (anonKey === serviceRoleKey) {
    throw new Error('Anon and service-role keys must be different.');
  }

  return {
    baseUrl: url.origin,
    anonKey,
    serviceRoleKey,
  };
}

export function redactErrorText(value, secrets = []) {
  let output = String(value ?? '');
  for (const secret of secrets) {
    if (secret) output = output.split(secret).join('[REDACTED]');
  }
  return output.replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/gi, 'Bearer [REDACTED]');
}
