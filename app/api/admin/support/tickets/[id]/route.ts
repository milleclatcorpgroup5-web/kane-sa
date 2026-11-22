import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';

const statuses = ['open', 'in_progress', 'waiting_customer', 'resolved', 'closed'] as const;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const { id } = await context.params;
  if (!uuidPattern.test(id)) return NextResponse.json({ error: 'Dosye a pa valid.' }, { status: 400 });
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  const status = typeof body?.status === 'string' ? body.status : '';
  const reply = typeof body?.reply === 'string' ? body.reply.trim() : null;
  if (!statuses.includes(status as typeof statuses[number]) || (reply !== null && (reply.length < 1 || reply.length > 4000))) {
    return NextResponse.json({ error: 'Estati oswa repons lan pa valid.' }, { status: 400 });
  }
  const { error } = await auth.supabase.rpc('admin_update_support_ticket', {
    p_ticket_id: id, p_status: status, p_reply: reply,
  });
  return error
    ? NextResponse.json({ error: 'Nou pa t kapab mete ajou dosye sipò a.' }, { status: 400 })
    : NextResponse.json({ ok: true });
}
