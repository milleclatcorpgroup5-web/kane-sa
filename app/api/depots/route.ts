import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { cleanText, positiveAmount } from '@/lib/validators';

const methods = ['moncash','natcash','cash','bank','other'] as const;
export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const { data: allowed } = await supabase.rpc('rate_limit_hit', { p_key: 'deposit', p_max: 10, p_window_seconds: 60 });
  if (!allowed) return NextResponse.json({ error: 'Twòp demann. Eseye ankò nan yon minit.' }, { status: 429 });
  try {
    const body = await request.json() as Record<string, unknown>;
    const planId = cleanText(body.plan_id, 80);
    const amount = positiveAmount(body.amount);
    const method = String(body.method ?? '');
    if (!planId || !amount || !methods.includes(method as typeof methods[number])) return NextResponse.json({ error: 'Plan, montan oswa metòd la pa valid.' }, { status: 400 });
    const { data, error } = await supabase.from('deposit_requests').insert({ plan_id: planId, user_id: user.id, amount, method: method as typeof methods[number], customer_reference: cleanText(body.customer_reference, 120) }).select('id').single();
    if (error) {
      const paused = error.message.includes('Demann depo yo sispann tanporèman');
      return NextResponse.json({ error: paused ? 'Nouvo demann depo yo sispann tanporèman. Tanpri eseye ankò pita.' : 'Nou pa kapab trete demann depo a kounye a. Verifye enfòmasyon yo epi eseye ankò.' }, { status: paused ? 503 : 400 });
    }
    return NextResponse.json({ id: data.id, status: 'pending' }, { status: 201 });
  } catch {
    return NextResponse.json({ error: 'Fòma demann lan pa valid.' }, { status: 400 });
  }
}
