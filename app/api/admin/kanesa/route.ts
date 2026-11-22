import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const schema = z.object({ plan_id: z.string().uuid(), kanesa_id: z.string().uuid().nullable() });
export async function POST(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'Done yo pa valid.' }, { status: 400 });
  const { error } = await auth.supabase.rpc('admin_assign_kanesa', { p_plan_id: parsed.data.plan_id, p_kanesa_id: parsed.data.kanesa_id });
  return error ? NextResponse.json({ error: error.message }, { status: 400 }) : NextResponse.json({ ok: true });
}
