import { notifyRequest } from '@/lib/notify';
import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { cleanText } from '@/lib/validators';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Context = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: Context) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const { id } = await context.params;
    if (!uuidPattern.test(id)) {
      return NextResponse.json({ error: 'Demann depo sa a pa valid.' }, { status: 400 });
    }
    const body: unknown = await request.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return NextResponse.json({ error: 'Enfòmasyon refi yo pa valid.' }, { status: 400 });
    }
    const note = cleanText((body as Record<string, unknown>).note, 500);
    const { error } = await auth.supabase.rpc('admin_reject_deposit', {
      p_request_id: id,
      p_note: note,
    });
    if (error) {
      return NextResponse.json(
        { error: 'Nou pa kapab refize demann depo sa a. Verifye estati li epi eseye ankò.' },
        { status: 409, headers: { 'Cache-Control': 'no-store' } },
      );
    }
    await notifyRequest(auth.supabase, 'deposit_requests', id, 'Depo pa konfime', 'Nou pa t kapab verifye depo a. Gade istorik ou.');
    return NextResponse.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json(
      { error: 'Demann refi a pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
