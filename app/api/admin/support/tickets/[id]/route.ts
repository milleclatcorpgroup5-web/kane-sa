import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const updateSchema = z.object({
  status: z.enum(['open', 'in_progress', 'waiting_customer', 'resolved', 'closed']),
  reply: z.string().trim().min(1).max(4000).nullable().optional(),
}).strict();
const noStore = { 'Cache-Control': 'no-store' };

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const { id } = await context.params;
    if (!uuidPattern.test(id)) {
      return NextResponse.json({ error: 'Dosye a pa valid.' }, { status: 400, headers: noStore });
    }

    const parsed = updateSchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Estati oswa repons lan pa valid.' },
        { status: 400, headers: noStore },
      );
    }

    const { error } = await auth.supabase.rpc('admin_update_support_ticket', {
      p_ticket_id: id,
      p_status: parsed.data.status,
      p_reply: parsed.data.reply ?? null,
    });

    if (error) {
      return NextResponse.json(
        { error: 'Nou pa t kapab mete ajou dosye sipò a.' },
        { status: 409, headers: noStore },
      );
    }
    return NextResponse.json({ ok: true }, { headers: noStore });
  } catch {
    return NextResponse.json(
      { error: 'Demann sipò a pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: noStore },
    );
  }
}
