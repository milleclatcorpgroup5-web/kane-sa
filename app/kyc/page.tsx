import { Header } from '@/components/header';
import { KycForm } from '@/components/compliance-client';
import { Notice } from '@/components/notice';
import { requireUser } from '@/lib/auth';
import { dateTime, statusLabel } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Verifikasyon idantite (KYC)' };

export default async function KycPage() {
  const { supabase, user } = await requireUser();
  const { data: k } = await supabase.from('kyc_profiles').select('status,review_note,submitted_at').eq('user_id', user.id).maybeSingle();
  return <><Header signedIn /><main className="container page"><div className="card form-card">
    <span className="eyebrow">Konfòmite</span><h1>Verifikasyon idantite</h1>
    <p className="muted">Pou retrè ki depase limit ki fikse a, nou bezwen verifye idantite w. Done yo itilize sèlman pou konfòmite.</p>
    {k ? <><p>Estati: <span className="pill">{statusLabel(k.status)}</span> <span className="small muted">voye {dateTime(k.submitted_at)}</span></p>
      {k.status === 'rejected' && <Notice tone="danger">Rejte{k.review_note ? `: ${k.review_note}` : '.'} Ou ka voye ankò.</Notice>}
      {k.status === 'verified' && <Notice tone="success">Idantite w verifye.</Notice>}
      {k.status === 'pending' && <Notice tone="info">Administrasyon an ap revize demann ou.</Notice>}</> : null}
    {(!k || k.status === 'rejected') && <KycForm />}
  </div></main></>;
}
