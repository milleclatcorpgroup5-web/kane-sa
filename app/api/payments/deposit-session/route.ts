import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getMoneyRailFlags } from '@/lib/money/feature-flags';

export async function POST() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401, headers: { 'Cache-Control': 'no-store' } });
  }

  const flags = getMoneyRailFlags();
  return NextResponse.json({
    error: 'Peman dijital poko aktive nan KANÈ SA. Demann sa a pa kreye yon sesyon peman epi li pa debite okenn kont.',
    code: 'MONEY_RAIL_LOCKED',
    realMoneyEnabled: flags.realMoneyEnabled,
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
