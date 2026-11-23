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
      return NextResponse.json({ error: 'Enfòmasyon konfimasyon yo pa valid.' }, { status: 400 });
    }
    const reference = cleanText((body as Record<string, unknown>).reference, 120);
    if (!reference) {
      return NextResponse.json({ error: 'Referans verifikasyon an obligatwa.' }, { status: 400 });
    }

    const { data, error } = await auth.supabase.rpc('admin_confirm_deposit', {
      p_request_id: id,
      p_verified_reference: reference,
    });

    if (error) {
      return NextResponse.json(
        { error: 'Nou pa kapab konfime depo sa a. Verifye estati demann lan epi eseye ankò.' },
        { status: 409, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    await notifyRequest(auth.supabase, 'deposit_requests', id, 'Depo konfime ✔', 'Depo ou a verifye. Balans ou mete ajou.');
    return NextResponse.json({ deposit_id: data }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json(
      { error: 'Demann konfimasyon an pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
