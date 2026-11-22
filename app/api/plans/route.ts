import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { cleanText, positiveAmount } from '@/lib/validators';

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const { data, error } = await supabase.from('plan_balances').select('plan_id,title,available_balance,status,has_goal,goal_amount').eq('user_id', user.id).eq('status', 'active').order('title');
  if (error) return NextResponse.json({ error: 'Nou pa rive chaje plan yo.' }, { status: 400 });
  return NextResponse.json({ plans: (data ?? []).map((p) => ({ id: p.plan_id, title: p.title, available_balance: p.available_balance, has_goal: p.has_goal, goal_amount: p.goal_amount })) });
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  try {
    const body = await request.json() as Record<string, unknown>;
    const title = cleanText(body.title, 80);
    const hasGoal = body.has_goal === true;
    const goalAmount = hasGoal ? positiveAmount(body.goal_amount) : null;
    const contribution = body.planned_contribution === null || body.planned_contribution === '' ? null : positiveAmount(body.planned_contribution);
    const frequencyValues = ['daily','weekly','monthly','flexible'] as const;
    const candidateFrequency = String(body.frequency);
    const frequency = frequencyValues.includes(candidateFrequency as typeof frequencyValues[number]) ? candidateFrequency as typeof frequencyValues[number] : 'flexible';
    if (!title || title.length < 2 || (hasGoal && !goalAmount) || (body.planned_contribution && !contribution)) {
      return NextResponse.json({ error: 'Verifye non plan an ak montan yo.' }, { status: 400 });
    }
    const { data, error } = await supabase.from('savings_plans').insert({ user_id: user.id, title, has_goal: hasGoal, goal_amount: goalAmount, planned_contribution: contribution, frequency }).select('id').single();
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    return NextResponse.json({ id: data.id }, { status: 201 });
  } catch {
    return NextResponse.json({ error: 'Fòma demann lan pa valid.' }, { status: 400 });
  }
}
