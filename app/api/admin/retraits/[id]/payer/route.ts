import { notifyRequest } from '@/lib/notify';
import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { cleanText } from '@/lib/validators';

type Context = { params: Promise<{ id: string }> };
export async function POST(request: Request, context: Context) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  try {
    const { id } = await context.params;
    const body = await request.json() as Record<string, unknown>;
    const reference = cleanText(body.reference, 120);
    if (!reference) return NextResponse.json({ error: 'Referans peman obligatwa.' }, { status: 400 });
    const { error } = await auth.supabase.rpc('admin_mark_withdrawal_paid', { p_request_id: id, p_payment_reference: reference });
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    await notifyRequest(auth.supabase, 'withdrawal_requests', id, 'Retrè peye ✔', 'Retrè ou peye. Resi a disponib nan istorik ou.');
    return NextResponse.json({ ok: true });
  } catch { return NextResponse.json({ error: 'Demann lan pa valid.' }, { status: 400 }); }
}
