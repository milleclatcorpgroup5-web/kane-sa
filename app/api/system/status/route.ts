import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const [{ data, error }, { data: settings }] = await Promise.all([
    supabase.from('system_controls').select('deposits_enabled,withdrawal_requests_enabled,public_notice').eq('id', 1).maybeSingle(),
    supabase.from('app_settings').select('maintenance_mode').eq('id', 1).maybeSingle(),
  ]);
  if (error || !data) return NextResponse.json({ error: 'Estati sistèm nan pa disponib.' }, { status: 500 });
  return NextResponse.json({ status: { ...data, maintenance_mode: settings?.maintenance_mode === true } }, { headers: { 'Cache-Control': 'no-store' } });
}
