import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

export async function PATCH(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  try {
    const body = await request.json() as Record<string, unknown>;
    const normal = Number(body.normal_withdrawal_fee_percent);
    const emergency = Number(body.emergency_withdrawal_fee_percent);
    if (!Number.isFinite(normal) || !Number.isFinite(emergency) || normal < 0 || normal > 25 || emergency < 0 || emergency > 25) return NextResponse.json({ error: 'Frè yo dwe ant 0 ak 25%.' }, { status: 400 });
    const { error } = await auth.supabase.from('app_settings').update({ normal_withdrawal_fee_percent: normal, emergency_withdrawal_fee_percent: emergency, fees_enabled: body.fees_enabled === true, maintenance_mode: body.maintenance_mode === true, updated_at: new Date().toISOString() }).eq('id',1);
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    return NextResponse.json({ ok: true });
  } catch { return NextResponse.json({ error: 'Fòma paramèt yo pa valid.' }, { status: 400 }); }
}
