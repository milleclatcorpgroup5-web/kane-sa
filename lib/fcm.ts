import { createServiceClient } from './supabase/service';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
let cache: { token: string; exp: number } | null = null;
const enc = new TextEncoder();

const b64u = (input: ArrayBuffer | string) => {
  const bytes = typeof input === 'string' ? enc.encode(input) : new Uint8Array(input);
  let s = '';
  bytes.forEach((b) => { s += String.fromCharCode(b); });
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

function account(): ServiceAccount | null {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return null;
  try { return JSON.parse(raw) as ServiceAccount; } catch { return null; }
}

/** OAuth2 pou FCM HTTP v1, siyen ak WebCrypto (mache sou Cloudflare Workers, pa bezwen firebase-admin). */
async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cache && cache.exp - 60 > now) return cache.token;
  const head = b64u(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64u(JSON.stringify({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 }));
  const der = Uint8Array.from(atob(sa.private_key.replace(/-----[A-Z ]+-----/g, '').replace(/\s/g, '')), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${head}.${claims}`));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${claims}.${b64u(sig)}` }),
  });
  if (!res.ok) throw new Error('Otantifikasyon FCM echwe.');
  const j = (await res.json()) as { access_token: string; expires_in: number };
  cache = { token: j.access_token, exp: now + j.expires_in };
  return j.access_token;
}

export async function sendPush(userId: string, title: string, body: string, link = '/historique') {
  const sa = account();
  if (!sa) return { sent: 0 };
  const db = createServiceClient();
  const { data: rows } = await db.from('push_tokens').select('token').eq('user_id', userId);
  if (!rows?.length) return { sent: 0 };
  const bearer = await accessToken(sa);
  let sent = 0;
  for (const { token } of rows) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: 'POST', headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message: { token, notification: { title, body }, webpush: { fcm_options: { link } } } }),
    });
    if (res.ok) sent++;
    else if (res.status === 404 || (await res.text()).includes('UNREGISTERED')) await db.from('push_tokens').delete().eq('token', token);
  }
  return { sent };
}
