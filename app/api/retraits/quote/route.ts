import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { cleanText, positiveAmount } from '@/lib/validators';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });

  try {
    const body = await request.json() as Record<string, unknown>;
    const planId = cleanText(body.plan_id, 80);
    const amount = positiveAmount(body.gross_amount);
    if (!planId || !uuidPattern.test(planId) || !amount || amount > 10000000) {
      return NextResponse.json({ error: 'Plan oswa montan an pa valid.' }, { status: 400 });
    }
    const { data, error } = await supabase.rpc('quote_withdrawal', {
      p_plan_id: planId,
      p_gross_amount: amount,
    });
    if (error) {
      const allowedMessages = ['Ou dwe konekte.', 'Montan retrè a pa valid.', 'Plan sa a pa disponib.', 'Balans disponib ou pa ase.', 'Twòp kalkil retrè. Eseye ankò nan yon minit.'];
      const safeMessage = allowedMessages.find((message) => error.message.includes(message)) || 'Nou pa rive kalkile frè retrè a. Eseye ankò.';
      return NextResponse.json({ error: safeMessage }, { status: safeMessage.startsWith('Twòp') ? 429 : 400 });
    }
    return NextResponse.json({ quote: data });
  } catch {
    return NextResponse.json({ error: 'Nou pa rive kalkile frè retrè a.' }, { status: 400 });
  }
}
