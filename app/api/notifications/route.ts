import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const { data, error } = await supabase.from('user_notifications')
    .select('id,kind,title,body,href,created_at,read_at')
    .eq('user_id', user.id).order('created_at', { ascending: false }).limit(100);
  if (error) return NextResponse.json({ error: 'Nou pa kapab chaje notifikasyon yo.' }, { status: 500 });
  return NextResponse.json({ notifications: data ?? [] });
}

export async function PATCH(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const body = await request.json().catch(() => null) as { id?: unknown } | null;
  const id = typeof body?.id === 'string' ? body.id : '';
  if (!/^[0-9a-f-]{36}$/i.test(id)) return NextResponse.json({ error: 'Notifikasyon an pa valid.' }, { status: 400 });
  const { error } = await supabase.rpc('mark_notification_read', { p_notification_id: id });
  return error
    ? NextResponse.json({ error: 'Nou pa t kapab mete notifikasyon an kòm li.' }, { status: 400 })
    : NextResponse.json({ ok: true });
}
