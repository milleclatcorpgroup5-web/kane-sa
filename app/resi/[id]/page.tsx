import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Header } from '@/components/header';
import { PrintButton } from '@/components/print-button';
import { requireUser } from '@/lib/auth';
import { dateTime, money } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Resi depo' };

export default async function ReceiptPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase, user } = await requireUser();
  const { data: d } = await supabase.from('deposits').select('id,plan_id,amount,method,verified_reference,created_at').eq('id', id).eq('user_id', user.id).maybeSingle();
  if (!d) notFound();
  const { data: plan } = await supabase.from('savings_plans').select('title').eq('id', d.plan_id).maybeSingle();
  const rows: [string, string][] = [['No. resi', `KS-${d.id.slice(0, 8).toUpperCase()}`], ['Plan', plan?.title ?? '—'], ['Montan konfime', money(d.amount)], ['Metòd', d.method], ['Referans verifye', d.verified_reference ?? '—'], ['Dat konfimasyon', dateTime(d.created_at)]];
  return <><Header signedIn /><main className="container page"><div className="card form-card">
    <span className="eyebrow">KANÈ SA</span><h1>Resi depo</h1>
    {rows.map(([k, v]) => <div className="tx-row" key={k}><span className="muted">{k}</span><b>{v}</b></div>)}
    <p className="small muted">Depo sa a verifye epi konfime pa administrasyon an.</p>
    <div className="actions"><PrintButton /><Link className="button secondary no-print" href="/historique">Tounen</Link></div>
  </div></main></>;
}
