import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  try {
    const body = await request.json() as { token?: unknown; platform?: unknown };
    if (typeof body.token !== 'string' || body.token.length < 20 || body.token.length > 4096) return NextResponse.json({ error: 'Token notifikasyon an pa valid.' }, { status: 400 });
    const platformValues = ['web','android','ios'] as const;
    const candidatePlatform = String(body.platform);
    const platform = platformValues.includes(candidatePlatform as typeof platformValues[number]) ? candidatePlatform as typeof platformValues[number] : 'web';
    const { error } = await supabase.from('push_tokens').upsert({ user_id: user.id, token: body.token, platform, last_seen_at: new Date().toISOString() }, { onConflict: 'token' });
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    return NextResponse.json({ ok: true });
  } catch { return NextResponse.json({ error: 'Demann lan pa valid.' }, { status: 400 }); }
}
