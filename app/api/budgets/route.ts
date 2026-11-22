import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { budgetSchema } from '@/lib/schemas';

export async function PUT(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const parsed = budgetSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: 'Bidjè a pa valid.' }, { status: 400 });
  const { error } = await supabase.from('budgets').upsert({ user_id: user.id, ...parsed.data, updated_at: new Date().toISOString() });
  return error ? NextResponse.json({ error: 'Pa t kapab sove bidjè a.' }, { status: 400 }) : NextResponse.json({ status: 'saved' });
}
