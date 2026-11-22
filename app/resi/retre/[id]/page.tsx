import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Header } from '@/components/header';
import { PrintButton } from '@/components/print-button';
import { requireUser } from '@/lib/auth';
import { dateTime, money } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Resi retrè' };

export default async function WithdrawalReceipt({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase, user } = await requireUser();
  const { data: w } = await supabase.from('withdrawal_requests').select('id,plan_id,kind,gross_amount,fee_amount,net_amount,payment_method,payment_reference,paid_at,status').eq('id', id).eq('user_id', user.id).maybeSingle();
  if (!w || w.status !== 'paid') notFound();
  const { data: plan } = await supabase.from('savings_plans').select('title').eq('id', w.plan_id).maybeSingle();
  const rows: [string, string][] = [['No. resi', `KR-${w.id.slice(0, 8).toUpperCase()}`], ['Plan', plan?.title ?? '—'], ['Kalite', w.kind === 'emergency' ? 'Ijans' : 'Nòmal'], ['Montan brit', money(w.gross_amount)], ['Frè', money(w.fee_amount)], ['Montan net peye', money(w.net_amount)], ['Metòd', w.payment_method ?? '—'], ['Referans peman', w.payment_reference ?? '—'], ['Dat peman', dateTime(w.paid_at)]];
  return <><Header signedIn /><main className="container page"><div className="card form-card">
    <span className="eyebrow">KANÈ SA</span><h1>Resi retrè</h1>
    {rows.map(([k, v]) => <div className="tx-row" key={k}><span className="muted">{k}</span><b>{v}</b></div>)}
    <div className="actions"><PrintButton /><Link className="button secondary no-print" href="/historique">Tounen</Link></div>
  </div></main></>;
}
