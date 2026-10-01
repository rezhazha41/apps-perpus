export class HttpError extends Error {
  constructor(message, status, body) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.body = body;
  }
}

export async function apiRequest(config, path, options = {}) {
  const {
    token,
    service = false,
    method = 'GET',
    body,
    headers = {},
    expect = 'json',
    allowStatus = [],
  } = options;
  const apiKey = service ? config.serviceRoleKey : config.anonKey;
  const requestHeaders = {
    apikey: apiKey,
    Authorization: `Bearer ${token ?? apiKey}`,
    ...headers,
  };
  let payload = body;
  if (body !== undefined && !(body instanceof Uint8Array) && typeof body !== 'string') {
    requestHeaders['Content-Type'] ??= 'application/json';
    payload = JSON.stringify(body);
  }

  const response = await fetch(`${config.baseUrl}${path}`, {
    method,
    headers: requestHeaders,
    body: payload,
    signal: AbortSignal.timeout(15_000),
  });
  const raw = expect === 'bytes'
    ? new Uint8Array(await response.arrayBuffer())
    : await response.text();
  const parsed = expect === 'bytes' || raw === ''
    ? raw
    : (() => {
        try { return JSON.parse(raw); } catch { return raw; }
      })();
  if (!response.ok && !allowStatus.includes(response.status)) {
    const detail = typeof parsed === 'string' ? parsed : JSON.stringify(parsed);
    throw new HttpError(`${method} ${path} failed (${response.status}): ${detail}`, response.status, parsed);
  }
  return { status: response.status, data: parsed, ok: response.ok };
}

export async function restInsert(config, table, row, options = {}) {
  const response = await apiRequest(config, `/rest/v1/${table}`, {
    ...options,
    method: 'POST',
    body: row,
    headers: { Prefer: 'return=representation', ...options.headers },
  });
  if (!Array.isArray(response.data) || response.data.length !== 1) {
    throw new Error(`Expected one inserted ${table} row.`);
  }
  return response.data[0];
}

export async function rpc(config, name, body, options = {}) {
  return apiRequest(config, `/rest/v1/rpc/${name}`, {
    ...options,
    method: 'POST',
    body,
  });
}
