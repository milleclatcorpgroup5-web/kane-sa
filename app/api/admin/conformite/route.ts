import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { complianceAction } from '@/lib/schemas.kyc';

export async function POST(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const parsed = complianceAction.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Done yo pa valid.' },
        { status: 400, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const action = parsed.data;
    const db = auth.supabase;
    const result = action.action === 'gate'
      ? await db.rpc('admin_set_gate', { p_key: action.key, p_done: action.done })
      : action.action === 'live'
        ? await db.rpc('admin_set_live_mode', { p_live: action.live })
        : action.action === 'kyc'
          ? await db.rpc('admin_review_kyc', {
              p_user_id: action.user_id,
              p_decision: action.decision,
              p_note: action.note ?? null,
            })
          : await db.rpc('admin_clear_aml_flag', { p_id: action.id });

    if (result.error) {
      return NextResponse.json(
        { error: 'Nou pa kapab mete ajou dosye konfòmite a. Verifye done yo epi eseye ankò.' },
        { status: 409, headers: { 'Cache-Control': 'no-store' } },
      );
    }
    return NextResponse.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json(
      { error: 'Demann konfòmite a pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
