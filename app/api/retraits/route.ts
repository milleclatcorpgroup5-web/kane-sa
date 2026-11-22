import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { cleanText, positiveAmount } from '@/lib/validators';
import { notifyRequest } from '@/lib/notify';

const methods = ['moncash', 'natcash', 'cash', 'bank'];
const reasons = ['medical', 'death', 'family_emergency', 'other'];
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type RpcResult = {
  id: string;
  status: 'pending' | 'approved' | 'rejected' | 'paid';
  kind: 'normal' | 'emergency';
  gross_amount: number;
  fee_percent: number;
  fee_amount: number;
  net_amount: number;
  authorization_mode: 'automatic' | 'manual_review' | 'legacy_manual';
  manual_review_reason: string | null;
  replayed?: boolean;
};

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Ou dwe konekte.' }, { status: 401 });

  try {
    const body = await request.json() as Record<string, unknown>;
    const planId = cleanText(body.plan_id, 80);
    const amount = positiveAmount(body.gross_amount);
    const kind = String(body.kind ?? '');
    const reason = body.reason_category == null ? null : String(body.reason_category);
    const method = String(body.payment_method ?? '');
    const expectedFeePercent = Number(body.expected_fee_percent);
    const idempotencyKey = String(body.idempotency_key ?? '');

    if (!planId || !uuidPattern.test(planId) || !amount || amount > 10000000
      || !['normal', 'emergency'].includes(kind) || !methods.includes(method)
      || !Number.isFinite(expectedFeePercent) || expectedFeePercent < 0 || expectedFeePercent > 25
      || !uuidPattern.test(idempotencyKey)) {
      return NextResponse.json({ error: 'Enfòmasyon demann lan pa valid. Rekalkile retrè a epi eseye ankò.' }, { status: 400 });
    }
    if (kind === 'emergency' && (!reason || !reasons.includes(reason))) {
      return NextResponse.json({ error: 'Chwazi rezon ijans lan.' }, { status: 400 });
    }

    const { data, error } = await supabase.rpc('request_withdrawal', {
      p_plan_id: planId,
      p_gross_amount: amount,
      p_kind: kind,
      p_reason_category: reason,
      p_reason_text: cleanText(body.reason_text, 500),
      p_payment_method: method,
      p_expected_fee_percent: expectedFeePercent,
      p_idempotency_key: idempotencyKey,
    });
    if (error) {
      const allowedMessages = [
        'Ou dwe konekte.', 'Kle sekirite demann lan obligatwa.', 'Metòd peman an pa valid.',
        'Twòp demann retrè.', 'Plan sa a pa disponib.', 'Montan retrè a pa valid.',
        'Balans disponib ou pa ase.', 'Règ plan an chanje depi kalkil la.',
        'Frè retrè a chanje.', 'KYC obligatwa pou retrè sa a.',
        'Chwazi rezon ijans lan.', 'Kle demann sa a deja itilize pou lòt done.',
        'Twòp kalkil retrè. Eseye ankò nan yon minit.',
        'Nouvo demann retrè yo sispann tanporèman. Demann ki deja egziste yo rete anba pwosesis nòmal.'
      ];
      const safeMessage = allowedMessages.find((message) => error.message.includes(message)) || 'Nou pa rive trete demann retrè a. Rekalkile epi eseye ankò.';
      return NextResponse.json({ error: safeMessage }, { status: safeMessage.startsWith('Twòp') ? 429 : safeMessage.startsWith('Nouvo demann retrè yo sispann') ? 503 : 400 });
    }
    const result = data as unknown as RpcResult;
    if (!result.replayed) {
      await notifyRequest(supabase, 'withdrawal_requests', result.id,
        result.authorization_mode === 'automatic' ? 'Retrè otorize otomatikman' : 'Retrè an verifikasyon',
        result.authorization_mode === 'automatic' ? 'Demann retrè a otorize. Peman an poko make kòm fèt.' : 'Demann retrè a bezwen yon verifikasyon sekirite.');
    }
    return NextResponse.json({ ...result, message: result.authorization_mode === 'automatic'
      ? 'Retrè a jwenn otorizasyon otomatik. Peman an ap tann egzekisyon oswa konfimasyon pa kanal peman an.'
      : 'Demann lan mete an atant pou verifikasyon sekirite.' }, { status: result.replayed ? 200 : 201 });
  } catch {
    return NextResponse.json({ error: 'Fòma demann lan pa valid.' }, { status: 400 });
  }
}
