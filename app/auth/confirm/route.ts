import { NextResponse } from 'next/server';
import type { EmailOtpType } from '@supabase/supabase-js';
import { createClient } from '@/lib/supabase/server';

const allowedTypes: EmailOtpType[] = ['signup','email','magiclink','invite','recovery','email_change'];

export async function GET(request: Request) {
  const url = new URL(request.url);
  const tokenHash = url.searchParams.get('token_hash');
  const type = url.searchParams.get('type');
  const destination = new URL('/connexion', url.origin);
  if (!tokenHash || !type || !allowedTypes.includes(type as EmailOtpType)) {
    destination.searchParams.set('error','Lyen verifikasyon an pa valid.');
    return NextResponse.redirect(destination);
  }
  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: type as EmailOtpType });
  if (error) destination.searchParams.set('error','Lyen verifikasyon an ekspire oswa li pa valid.');
  else destination.searchParams.set('verified','1');
  return NextResponse.redirect(destination);
}
