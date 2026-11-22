import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

export async function GET() {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const { data, error } = await auth.supabase.from('system_controls').select('*').eq('id', 1).maybeSingle();
  if (error || !data) return NextResponse.json({ error: 'Kontwòl sistèm yo pa disponib.' }, { status: 500 });
  return NextResponse.json({ controls: data });
}

export async function PATCH(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  if (typeof body?.deposits_enabled !== 'boolean' || typeof body?.withdrawal_requests_enabled !== 'boolean'
    || (body.public_notice !== null && body.public_notice !== undefined && typeof body.public_notice !== 'string')) {
    return NextResponse.json({ error: 'Paramèt kontwòl yo pa valid.' }, { status: 400 });
  }
  const notice = typeof body.public_notice === 'string' ? body.public_notice.trim() : null;
  if (notice && notice.length > 320) return NextResponse.json({ error: 'Mesaj la pa dwe depase 320 karaktè.' }, { status: 400 });
  const { error } = await auth.supabase.rpc('admin_set_system_controls', {
    p_deposits_enabled: body.deposits_enabled,
    p_withdrawal_requests_enabled: body.withdrawal_requests_enabled,
    p_public_notice: notice,
  });
  return error
    ? NextResponse.json({ error: 'Nou pa t kapab mete ajou kontwòl sistèm yo.' }, { status: 400 })
    : NextResponse.json({ ok: true });
}
