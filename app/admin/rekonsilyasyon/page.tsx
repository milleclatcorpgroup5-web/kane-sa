import Link from 'next/link';
import { Header } from '@/components/header';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Rekonsilyasyon entèn' };
const labels: Record<string, string> = {
  negative_balance: 'Balans negatif', negative_available_balance: 'Balans disponib negatif',
  ledger_unbalanced: 'Tranzaksyon ledger ki pa balanse', deposit_missing_ledger: 'Depo ki manke antre ledger',
  paid_withdrawal_missing_ledger: 'Retrè peye ki manke antre ledger', ledger_plan_balance_mismatch: 'Diferans ant ledger ak balans plan',
};

export default async function ReconciliationPage() {
  const { supabase } = await requireRole(['admin']);
  const { data, error } = await supabase.from('admin_reconciliation_checks').select('*');
  const checks = data ?? [];
  const issues = checks.reduce((sum, check) => sum + Number(check.violations), 0);
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Global Control · Finans</span><h1>Rekonsilyasyon entèn</h1><p className="muted">Kontwòl konsistans ant balans plan yo ak ledger doub-antre a.</p></div><Link href="/admin">← Admin</Link></div><div className="notice notice-warning"><strong>Limit verifikasyon:</strong> paj sa a konpare done entèn KANÈ SA sèlman. Li pa konpare ak deklarasyon MonCash, NatCash oswa bank; sa mande API/rapò founisè yo ak yon pwosesis rekonsilyasyon ekstèn.</div><section className="grid"><article className="card"><div className="metric-label">Kontwòl yo</div><div className="metric">{checks.length}</div></article><article className="card"><div className="metric-label">Total vyolasyon</div><div className="metric">{issues}</div></article><article className="card"><div className="metric-label">Eta</div><div className="metric">{error ? 'Erè' : issues ? 'Revize' : 'OK'}</div></article></section><div className="section-title"><h2>Rezilta kontwòl yo</h2></div><div className="card">{error ? <p className="muted">Nou pa t kapab chaje rapò a. Verifye migration 0007 ak dwa admin yo.</p> : checks.map((check) => <div className="tx-row" key={check.check_name}><div><strong>{labels[check.check_name] || check.check_name}</strong><div className="small muted">Nivo: {check.severity === 'critical' ? 'Kritik' : 'Wo'}</div></div><span className={`pill ${check.violations ? 'pill-danger' : 'pill-success'}`}>{check.violations} pwoblèm</span></div>)}</div><p className="muted small">Yon rezilta 0 vle di tès entèn sa a pa jwenn diferans nan done li analize; sa pa ranplase odit kontab oswa verifikasyon bank.</p></main></>;
}
