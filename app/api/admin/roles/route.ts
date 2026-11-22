import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const schema = z.object({ user_id: z.string().uuid(), role: z.enum(['kliyan', 'kanesa', 'admin']) });
export async function POST(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'Done yo pa valid.' }, { status: 400 });
  const { error } = await auth.supabase.rpc('admin_set_role', { p_user_id: parsed.data.user_id, p_role: parsed.data.role });
  return error ? NextResponse.json({ error: error.message }, { status: 400 }) : NextResponse.json({ ok: true });
}
