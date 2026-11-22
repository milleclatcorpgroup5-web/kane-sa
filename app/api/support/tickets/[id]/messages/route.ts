import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  if (!uuidPattern.test(id)) return NextResponse.json({ error: 'Dosye a pa valid.' }, { status: 400 });
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const body = await request.json().catch(() => null) as { message?: unknown } | null;
  const message = typeof body?.message === 'string' ? body.message.trim() : '';
  if (message.length < 1 || message.length > 4000) return NextResponse.json({ error: 'Mesaj la dwe gen 1 a 4000 karaktè.' }, { status: 400 });
  const { error } = await supabase.from('support_ticket_messages').insert({ ticket_id: id, sender_id: user.id, body: message });
  if (error) return NextResponse.json({ error: 'Nou pa t kapab voye mesaj la. Dosye a ka fèmen oswa ou pa gen aksè.' }, { status: 403 });
  return NextResponse.json({ ok: true }, { status: 201 });
}
