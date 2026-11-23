import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const schema = z.object({
  plan_id: z.string().uuid(),
  kanesa_id: z.string().uuid().nullable(),
}).strict();

export async function POST(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const parsed = schema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'ID plan an oswa ID Kanèsa a pa valid.' },
        { status: 400, headers: { 'Cache-Control': 'no-store' } },
      );
    }
    const { error } = await auth.supabase.rpc('admin_assign_kanesa', {
      p_plan_id: parsed.data.plan_id,
      p_kanesa_id: parsed.data.kanesa_id,
    });
    if (error) {
      return NextResponse.json(
        { error: 'Nou pa kapab chanje responsab plan sa a. Verifye plan an ak dwa administratè yo.' },
        { status: 409, headers: { 'Cache-Control': 'no-store' } },
      );
    }
    return NextResponse.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json(
      { error: 'Demann lan pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
