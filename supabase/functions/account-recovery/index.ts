import { createClient } from 'npm:@supabase/supabase-js@2';

import {
  generateRecoveryCode,
  normalizeRecoveryCode,
  recoveryInputError,
  sha256Hex,
} from './helpers.mjs';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function bearerToken(request) {
  const value = request.headers.get('Authorization') ?? '';
  return value.startsWith('Bearer ') ? value.slice(7).trim() : '';
}

function requiredEnvironment() {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceRoleKey) throw new Error('Recovery service is not configured.');
  return { url, serviceRoleKey };
}

async function issueChallenge(client, request, body) {
  const jwt = bearerToken(request);
  if (!jwt) return json(401, { message: 'Sesi pengurus diperlukan.' });
  const { data: authData, error: authError } = await client.auth.getUser(jwt);
  if (authError || !authData.user) return json(401, { message: 'Sesi pengurus tidak valid.' });

  const targetUserId = String(body.target_user_id ?? '');
  const expectedEmail = String(body.new_email ?? '').trim().toLowerCase() || null;
  const code = generateRecoveryCode();
  const codeHash = await sha256Hex(normalizeRecoveryCode(code));
  const { data, error } = await client.rpc('issue_account_recovery_challenge', {
    p_issued_by: authData.user.id,
    p_user_id: targetUserId,
    p_code_hash: codeHash,
    p_expected_email: expectedEmail,
  });
  if (error || !Array.isArray(data) || !data[0]?.challenge_id) {
    return json(400, { message: 'Kode pemulihan belum dapat dibuat.' });
  }
  return json(200, {
    challenge_id: data[0].challenge_id,
    code,
    expires_at: data[0].expires_at,
  });
}

async function redeemChallenge(client, body) {
  const challengeId = body.challenge_id;
  const code = normalizeRecoveryCode(body.code);
  const password = body.password;
  const inputError = recoveryInputError({ challengeId, code, password });
  if (inputError) return json(400, { message: inputError });

  const codeHash = await sha256Hex(code);
  const { data, error } = await client.rpc('consume_account_recovery_challenge', {
    p_challenge_id: challengeId,
    p_code_hash: codeHash,
  });
  const result = Array.isArray(data) ? data[0] : null;
  if (error || result?.success !== true || !result.user_id) {
    return json(400, { message: 'Kode pemulihan salah, kedaluwarsa, atau sudah digunakan.' });
  }

  const attributes = { password };
  if (result.expected_email) {
    attributes.email = result.expected_email;
    attributes.email_confirm = true;
  }
  const { error: updateError } = await client.auth.admin.updateUserById(
    result.user_id,
    attributes,
  );
  if (updateError) {
    return json(500, {
      message: 'Akun belum berhasil dipulihkan. Minta pengurus membuat kode baru.',
    });
  }

  await client.rpc('revoke_member_sessions', { p_user_id: result.user_id });
  await client.from('audit_logs').insert({
    actor_id: result.issued_by,
    action: 'ACCOUNT_RECOVERY_COMPLETED',
    table_name: 'profiles',
    record_id: result.user_id,
    new_data: {
      challenge_id: challengeId,
      email_changed: result.expected_email != null,
    },
  });
  return json(200, { message: 'Akses akun berhasil dipulihkan.' });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json(405, { message: 'Metode tidak didukung.' });
  try {
    const { url, serviceRoleKey } = requiredEnvironment();
    const body = await request.json();
    const client = createClient(url, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    if (body.action === 'issue') return await issueChallenge(client, request, body);
    if (body.action === 'redeem') return await redeemChallenge(client, body);
    return json(400, { message: 'Tindakan pemulihan tidak valid.' });
  } catch {
    return json(500, { message: 'Layanan pemulihan belum dapat digunakan.' });
  }
});
