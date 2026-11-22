import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { complianceAction } from '@/lib/schemas.kyc';

export async function POST(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const p = complianceAction.safeParse(await request.json().catch(() => null));
  if (!p.success) return NextResponse.json({ error: 'Done yo pa valid.' }, { status: 400 });
  const a = p.data, db = auth.supabase;
  const { error } = a.action === 'gate' ? await db.rpc('admin_set_gate', { p_key: a.key, p_done: a.done })
    : a.action === 'live' ? await db.rpc('admin_set_live_mode', { p_live: a.live })
    : a.action === 'kyc' ? await db.rpc('admin_review_kyc', { p_user_id: a.user_id, p_decision: a.decision, p_note: a.note ?? null })
    : await db.rpc('admin_clear_aml_flag', { p_id: a.id });
  return error ? NextResponse.json({ error: error.message }, { status: 400 }) : NextResponse.json({ ok: true });
}
