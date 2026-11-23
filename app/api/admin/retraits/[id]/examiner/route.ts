import { notifyRequest } from '@/lib/notify';
import { NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { cleanText } from '@/lib/validators';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const bodySchema = z.object({
  decision: z.enum(['approved', 'rejected']),
  note: z.string().max(1000).optional(),
}).strict();
type Context = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: Context) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  try {
    const { id } = await context.params;
    if (!uuidPattern.test(id)) {
      return NextResponse.json({ error: 'Demann retrè sa a pa valid.' }, { status: 400 });
    }
    const parsed = bodySchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json({ error: 'Desizyon oswa nòt revizyon an pa valid.' }, { status: 400 });
    }
    const { decision } = parsed.data;
    const { error } = await auth.supabase.rpc('admin_review_withdrawal', {
      p_request_id: id,
      p_decision: decision,
      p_note: cleanText(parsed.data.note, 500),
    });
    if (error) {
      return NextResponse.json(
        { error: 'Nou pa kapab trete revizyon retrè sa a. Verifye estati li epi eseye ankò.' },
        { status: 409, headers: { 'Cache-Control': 'no-store' } },
      );
    }
    await notifyRequest(
      auth.supabase,
      'withdrawal_requests',
      id,
      decision === 'approved' ? 'Retrè apwouve' : 'Retrè refize',
      decision === 'approved' ? 'Demann retrè ou apwouve. Peman an ap vini.' : 'Demann retrè ou pa t apwouve. Gade istorik ou.',
    );
    return NextResponse.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json(
      { error: 'Demann revizyon an pa valid oswa sèvis la pa disponib.' },
      { status: 400, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
