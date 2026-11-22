import Link from 'next/link';
import { Header } from '@/components/header';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Sante sistèm' };

export default async function SystemHealthPage() {
  const { supabase } = await requireRole(['admin']);
  const started = Date.now();
  const [{ count: profileCount, error: dbError }, { data: checks, error: checksError }, { data: controls }, { data: settings }] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('integrity_checks').select('check_name,violations'),
    supabase.from('system_controls').select('deposits_enabled,withdrawal_requests_enabled,updated_at').eq('id', 1).maybeSingle(),
    supabase.from('app_settings').select('maintenance_mode').eq('id', 1).maybeSingle(),
  ]);
  const elapsed = Date.now() - started;
  const violations = (checks ?? []).reduce((sum, row) => sum + Number(row.violations), 0);
  const dbHealthy = !dbError && !checksError && !!controls;
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Global Control</span><h1>Sante sistèm</h1><p className="muted">Kontwòl bazdone ak paramèt sèvis KANÈ SA.</p></div><Link href="/admin">← Admin</Link></div><div className="notice notice-warning">Sa se yon tès koneksyon Supabase ak kèk kontwòl entèn. Li pa montre Cloudflare CPU, erè Worker, disponiblite entènèt, Firebase delivery oswa siveyans ekstèn.</div><section className="grid"><article className="card"><div className="metric-label">Koneksyon bazdone</div><div className="metric">{dbHealthy ? 'OK' : 'Erè'}</div><p className="small muted">{elapsed} ms pou chèk yo retounen</p></article><article className="card"><div className="metric-label">Kantite kont</div><div className="metric">{profileCount ?? '—'}</div></article><article className="card"><div className="metric-label">Vyolasyon entegrite</div><div className="metric">{checksError ? '—' : violations}</div></article><article className="card"><div className="metric-label">Mòd antretyen</div><div className="metric">{settings?.maintenance_mode ? 'Aktif' : 'Inaktif'}</div></article></section><div className="section-title"><h2>Kontwòl operasyon</h2></div><div className="card"><div className="tx-row"><span>Nouvo demann depo</span><strong>{controls?.deposits_enabled ? 'Aktive' : 'Sispann'}</strong></div><div className="tx-row"><span>Nouvo demann retrè</span><strong>{controls?.withdrawal_requests_enabled ? 'Aktive' : 'Sispann'}</strong></div><div className="tx-row"><span>Dènye mizajou kontwòl</span><strong>{controls?.updated_at ? new Date(controls.updated_at).toLocaleString('fr-HT') : '—'}</strong></div><div className="actions"><Link className="button secondary" href="/admin/rekonsilyasyon">Kontwòl rekonsilyasyon</Link><Link className="button secondary" href="/admin">Jere switch yo</Link></div></div></main></>;
}
