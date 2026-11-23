import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const controlsSchema = z.object({
  deposits_enabled: z.boolean(),
  withdrawal_requests_enabled: z.boolean(),
  public_notice: z.string().trim().max(320).nullable().optional(),
}).strict();

const noStore = { 'Cache-Control': 'no-store' };

export async function GET() {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const { data, error } = await auth.supabase
      .from('system_controls')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    if (error || !data) {
      return NextResponse.json(
        { error: 'Kontwòl sistèm yo pa disponib.' },
        { status: 503, headers: noStore },
      );
    }
    return NextResponse.json({ controls: data }, { headers: noStore });
  } catch {
    return NextResponse.json(
      { error: 'Sèvis kontwòl sistèm yo pa disponib.' },
      { status: 503, headers: noStore },
    );
  }
}

export async function PATCH(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const parsed = controlsSchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Paramèt kontwòl yo pa valid. Verifye switch yo ak mesaj piblik la.' },
        { status: 400, headers: noStore },
      );
    }

    const { error } = await auth.supabase.rpc('admin_set_system_controls', {
      p_deposits_enabled: parsed.data.deposits_enabled,
      p_withdrawal_requests_enabled: parsed.data.withdrawal_requests_enabled,
      p_public_notice: parsed.data.public_notice ?? null,
    });

    if (error) {
      return NextResponse.json(
        { error: 'Nou pa t kapab mete ajou kontwòl sistèm yo.' },
        { status: 409, headers: noStore },
      );
    }
    return NextResponse.json({ ok: true }, { headers: noStore });
  } catch {
    return NextResponse.json(
      { error: 'Demann kontwòl la pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: noStore },
    );
  }
}
