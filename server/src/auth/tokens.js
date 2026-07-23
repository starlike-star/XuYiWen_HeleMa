import crypto from 'node:crypto';

function encode(value) {
  return Buffer.from(value).toString('base64url');
}

export function hashToken(token) {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

export function createAccessToken({ userId, sessionId, secret, expiresInSeconds, now = new Date() }) {
  const header = encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = encode(JSON.stringify({
    sub: String(userId),
    sid: String(sessionId),
    iat: Math.floor(now.getTime() / 1000),
    exp: Math.floor(now.getTime() / 1000) + expiresInSeconds
  }));
  const unsigned = `${header}.${payload}`;
  const signature = crypto.createHmac('sha256', secret).update(unsigned).digest('base64url');
  return `${unsigned}.${signature}`;
}

export function verifyAccessToken(token, secret, now = new Date()) {
  const parts = typeof token === 'string' ? token.split('.') : [];
  if (parts.length !== 3) return null;
  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = crypto.createHmac('sha256', secret).update(unsigned).digest();
  let supplied;
  try {
    supplied = Buffer.from(parts[2], 'base64url');
  } catch {
    return null;
  }
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (!payload.sub || !payload.sid || !Number.isInteger(payload.exp) ||
        payload.exp <= Math.floor(now.getTime() / 1000)) return null;
    return { userId: Number(payload.sub), sessionId: Number(payload.sid), expiresAt: payload.exp };
  } catch {
    return null;
  }
}

export function createRefreshToken(sessionId) {
  return `${sessionId}.${crypto.randomBytes(32).toString('base64url')}`;
}

export function refreshSessionId(token) {
  if (typeof token !== 'string') return null;
  const [id, secret, extra] = token.split('.');
  const sessionId = Number(id);
  return !extra && secret && Number.isSafeInteger(sessionId) && sessionId > 0 ? sessionId : null;
}
