import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const schema = z.object({
  user_id: z.string().uuid(),
  role: z.enum(['kliyan', 'kanesa', 'admin']),
}).strict();

export async function POST(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const parsed = schema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'ID itilizatè a oswa wòl la pa valid.' },
        { status: 400, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    if (parsed.data.user_id === auth.user.id && parsed.data.role !== 'admin') {
      return NextResponse.json(
        { error: 'Ou pa kapab retire pwòp dwa administratè ou pandan sesyon sa a.' },
        { status: 409, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const { error } = await auth.supabase.rpc('admin_set_role', {
      p_user_id: parsed.data.user_id,
      p_role: parsed.data.role,
    });

    if (error) {
      return NextResponse.json(
        { error: 'Nou pa kapab modifye wòl itilizatè a. Verifye itilizatè a ak dwa administratè yo.' },
        { status: 400, headers: { 'Cache-Control': 'no-store' } },
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
