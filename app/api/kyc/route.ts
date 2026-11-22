import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { kycSchema } from '@/lib/schemas.kyc';

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });
  const p = kycSchema.safeParse(await request.json().catch(() => null));
  if (!p.success) return NextResponse.json({ error: 'Done yo pa valid.' }, { status: 400 });
  const { error } = await supabase.rpc('submit_kyc', { p_legal_name: p.data.legal_name, p_dob: p.data.date_of_birth, p_address: p.data.address, p_doc_type: p.data.document_type, p_doc_last4: p.data.document_last4 });
  return error ? NextResponse.json({ error: error.message }, { status: 400 }) : NextResponse.json({ ok: true });
}
