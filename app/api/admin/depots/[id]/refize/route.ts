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
    const { error } = await auth.supabase.rpc('admin_reject_deposit', { p_request_id: id, p_note: cleanText(body.note, 500) });
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    await notifyRequest(auth.supabase, 'deposit_requests', id, 'Depo pa konfime', 'Nou pa t kapab verifye depo a. Gade istorik ou.');
    return NextResponse.json({ ok: true });
  } catch { return NextResponse.json({ error: 'Demann lan pa valid.' }, { status: 400 }); }
}
