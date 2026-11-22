import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { transactionSchema } from '@/lib/schemas';

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const { data: allowed } = await supabase.rpc('rate_limit_hit', { p_key: 'tx', p_max: 30, p_window_seconds: 60 });
  if (!allowed) return NextResponse.json({ error: 'Twòp demann. Eseye ankò nan yon minit.' }, { status: 429 });
  const key = request.headers.get('idempotency-key');
  if (!key || key.length > 80) return NextResponse.json({ error: 'Kle idempotans manke.' }, { status: 400 });
  const parsed = transactionSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'Done yo pa valid.' }, { status: 400 });
  const { error } = await supabase.from('transactions').insert({ user_id: user.id, ...parsed.data, note: parsed.data.note ?? null, idempotency_key: key });
  if (error?.code === '23505') return NextResponse.json({ status: 'duplicate' }, { status: 200 });
  if (error) return NextResponse.json({ error: 'Pa t kapab anrejistre tranzaksyon an.' }, { status: 400 });
  return NextResponse.json({ status: 'created' }, { status: 201 });
}

export async function DELETE(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const id = new URL(request.url).searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'ID manke.' }, { status: 400 });
  const { error } = await supabase.from('transactions').delete().eq('id', id).eq('user_id', user.id);
  return error ? NextResponse.json({ error: 'Pa t kapab efase.' }, { status: 400 }) : NextResponse.json({ status: 'deleted' });
}
