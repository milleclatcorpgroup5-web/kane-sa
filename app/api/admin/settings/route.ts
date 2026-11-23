import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const settingsSchema = z.object({
  normal_withdrawal_fee_percent: z.number().finite().min(0).max(25).optional(),
  emergency_withdrawal_fee_percent: z.number().finite().min(0).max(25).optional(),
  fees_enabled: z.boolean().optional(),
  maintenance_mode: z.boolean().optional(),
}).strict().refine((value) => Object.keys(value).length > 0, {
  message: 'Bay omwen yon paramèt pou modifye.',
});

export async function PATCH(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const body: unknown = await request.json();
    const parsed = settingsSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Paramèt yo pa valid. Frè yo dwe ant 0 ak 25%, epi switch yo dwe vre oswa fo.' },
        { status: 400, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const update = {
      ...parsed.data,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await auth.supabase
      .from('app_settings')
      .update(update)
      .eq('id', 1)
      .select('id')
      .maybeSingle();

    if (error) {
      return NextResponse.json(
        { error: 'Nou pa kapab anrejistre paramèt yo kounye a. Verifye dwa aksè yo epi eseye ankò.' },
        { status: 503, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    if (!data) {
      return NextResponse.json(
        { error: 'Paramèt sistèm yo pa jwenn. Kontakte sipò teknik.' },
        { status: 404, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    return NextResponse.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json(
      { error: 'Fòma demann lan pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
