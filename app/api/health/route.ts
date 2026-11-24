import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export function GET() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  return NextResponse.json(
    {
      status: 'ok',
      service: 'kane-sa',
      runtime: {
        supabaseUrlConfigured: Boolean(supabaseUrl),
        supabaseAnonKeyConfigured: Boolean(supabaseAnonKey),
      },
      time: new Date().toISOString(),
    },
    { headers: { 'Cache-Control': 'no-store, max-age=0' } },
  );
}
