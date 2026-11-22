import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

const categories = ['account', 'deposit', 'withdrawal', 'savings_plan', 'security', 'other'] as const;

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const { data, error } = await supabase.from('support_tickets')
    .select('id,subject,category,status,priority,created_at,updated_at,last_message_at')
    .eq('user_id', user.id).order('last_message_at', { ascending: false }).limit(50);
  if (error) return NextResponse.json({ error: 'Nou pa kapab chaje dosye sipò yo.' }, { status: 500 });
  return NextResponse.json({ tickets: data ?? [] });
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  const subject = typeof body?.subject === 'string' ? body.subject.trim() : '';
  const category = typeof body?.category === 'string' ? body.category : '';
  const message = typeof body?.message === 'string' ? body.message.trim() : '';
  if (subject.length < 4 || subject.length > 120 || !categories.includes(category as typeof categories[number]) || message.length < 1 || message.length > 4000) {
    return NextResponse.json({ error: 'Sijè, kategori oswa mesaj la pa valid.' }, { status: 400 });
  }
  const { data, error } = await supabase.rpc('create_support_ticket', {
    p_subject: subject, p_category: category, p_initial_message: message,
  });
  if (error) {
    const messageSafe = error.message.includes('twòp dosye')
      ? 'Ou kreye twòp dosye sipò. Eseye ankò pita.'
      : 'Nou pa t kapab louvri dosye sipò a. Verifye enfòmasyon yo epi eseye ankò.';
    return NextResponse.json({ error: messageSafe }, { status: error.message.includes('twòp dosye') ? 429 : 400 });
  }
  return NextResponse.json({ id: data, status: 'open' }, { status: 201 });
}
