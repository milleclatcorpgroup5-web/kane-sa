import Link from 'next/link';
import { Header } from '@/components/header';
import { requireRole } from '@/lib/auth';
import { money } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Rapò global' };

export default async function GlobalReportsPage() {
  const { supabase } = await requireRole(['admin']);
  const [{ count: userCount }, { data: deposits }, { data: withdrawals }, { data: plans }, { count: openTickets }] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('deposits').select('amount').limit(10000),
    supabase.from('withdrawal_requests').select('gross_amount,fee_amount,net_amount,status').limit(10000),
    supabase.from('plan_balances').select('balance,available_balance').limit(10000),
    supabase.from('support_tickets').select('id', { count: 'exact', head: true }).not('status', 'in', '(resolved,closed)'),
  ]);
  const totalDeposits = (deposits ?? []).reduce((sum, row) => sum + Number(row.amount), 0);
  const paidWithdrawals = (withdrawals ?? []).filter((row) => row.status === 'paid');
  const totalPaid = paidWithdrawals.reduce((sum, row) => sum + Number(row.gross_amount), 0);
  const totalFees = paidWithdrawals.reduce((sum, row) => sum + Number(row.fee_amount), 0);
  const totalBalance = (plans ?? []).reduce((sum, row) => sum + Number(row.balance), 0);
  const availableBalance = (plans ?? []).reduce((sum, row) => sum + Number(row.available_balance), 0);
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Global Control</span><h1>Rapò ak analiz</h1><p className="muted">Rezime agregasyon done aplikasyon an; valè yo pa ranplase rekonsilyasyon ekstèn.</p></div><div className="actions"><Link className="button" href="/api/admin/rapo/export">Ekspòte CSV</Link><Link href="/admin">← Admin</Link></div></div><section className="grid"><article className="card"><div className="metric-label">Kont itilizatè</div><div className="metric">{userCount ?? 0}</div></article><article className="card"><div className="metric-label">Depo konfime</div><div className="metric">{money(totalDeposits)}</div></article><article className="card"><div className="metric-label">Retrè ki make peye (brit)</div><div className="metric">{money(totalPaid)}</div></article><article className="card"><div className="metric-label">Frè sou retrè peye</div><div className="metric">{money(totalFees)}</div></article><article className="card"><div className="metric-label">Balans plan yo</div><div className="metric">{money(totalBalance)}</div></article><article className="card"><div className="metric-label">Balans disponib</div><div className="metric">{money(availableBalance)}</div></article><article className="card"><div className="metric-label">Dosye sipò ouvè</div><div className="metric">{openTickets ?? 0}</div></article></section><div className="notice notice-info">Rapò sa a itilize jiska 10,000 liy pou kèk total. Pou gwo echèl, nou dwe deplase agregasyon yo nan fonksyon SQL/materialized views epi ajoute filtè dat.</div><div className="actions"><Link className="button secondary" href="/admin/rekonsilyasyon">Louvri rekonsilyasyon entèn</Link><Link className="button secondary" href="/admin/sipo">Louvri sant sipò</Link></div></main></>;
}
