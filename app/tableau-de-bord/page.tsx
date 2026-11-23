import Link from 'next/link';
import { Header } from '@/components/header';
import { Notice } from '@/components/notice';
import { money, statusLabel } from '@/lib/format';
import { requireUser } from '@/lib/auth';
import { EnableNotifications } from '@/components/enable-notifications';

export const dynamic = 'force-dynamic';

export default async function DashboardPage() {
  const { supabase, user } = await requireUser();
  const [{ data: profile }, { data: plans }, { data: deposits }, { data: withdrawals }, { data: systemControls }] = await Promise.all([
    supabase.from('profiles').select('full_name,role').eq('id', user.id).maybeSingle(),
    supabase.from('plan_balances').select('*').eq('user_id', user.id).order('plan_id'),
    supabase.from('deposit_requests').select('id,amount,status,created_at,method').eq('user_id', user.id).order('created_at', { ascending: false }).limit(5),
    supabase.from('withdrawal_requests').select('id,gross_amount,net_amount,status,created_at,kind').eq('user_id', user.id).order('created_at', { ascending: false }).limit(5),
    supabase.from('system_controls').select('deposits_enabled,withdrawal_requests_enabled,public_notice').eq('id', 1).maybeSingle(),
  ]);

  const total = (plans ?? []).reduce((sum, plan) => sum + Number(plan.balance || 0), 0);
  const pendingDeposits = deposits?.filter(item => item.status === 'pending').length ?? 0;
  const pendingWithdrawals = withdrawals?.filter(item => item.status === 'pending' || item.status === 'approved').length ?? 0;
  const activities = [
    ...(deposits ?? []).map(item => ({ ...item, type: 'Depo', amount: item.amount })),
    ...(withdrawals ?? []).map(item => ({ ...item, type: 'Retrè', amount: item.gross_amount })),
  ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()).slice(0, 6);

  return (
    <>
      <Header signedIn />
      <main className="container page dashboard-page">
        <section className="dashboard-welcome">
          <div>
            <span className="eyebrow">ESPAS PÈSONÈL</span>
            <h1>Bonjou, {profile?.full_name || 'kliyan'} 👋</h1>
            <p>Men yon apèsi sou ekonomi ou ak dènye aktivite kont ou.</p>
          </div>
          <span className="pill">Wòl: {statusLabel(profile?.role || 'kliyan')}</span>
        </section>

        <div className="dashboard-notices">
          <Notice tone="warning">Se sèlman depo administrasyon an verifye ki antre nan balans ou. Yon demann depo pa vle di lajan an deja resevwa.</Notice>
          {systemControls?.public_notice && <Notice tone="info">{systemControls.public_notice}</Notice>}
          {systemControls && (!systemControls.deposits_enabled || !systemControls.withdrawal_requests_enabled) && (
            <Notice tone="warning">Gen yon fonksyon ki sispann tanporèman: {systemControls.deposits_enabled ? 'depo yo disponib' : 'nouvo demann depo yo sispann'}; {systemControls.withdrawal_requests_enabled ? 'nouvo retrè yo disponib' : 'nouvo demann retrè yo sispann'}.</Notice>
          )}
        </div>

        <section className="dashboard-summary" aria-label="Rezime ekonomi">
          <article className="dashboard-balance-card">
            <span className="dashboard-card-label">BALANS TOTAL KONFIME</span>
            <strong>{money(total)}</strong>
            <span>Sou tout plan ekonomi ou yo</span>
          </article>
          <article className="card dashboard-stat">
            <span className="dashboard-card-label">PLAN EKONOMI</span>
            <strong>{plans?.length ?? 0}</strong>
            <Link href="/plans/nouveau">Gade oswa kreye plan →</Link>
          </article>
          <article className="card dashboard-stat">
            <span className="dashboard-card-label">DEPO AN ATANT</span>
            <strong>{pendingDeposits}</strong>
            <Link href="/historique">Swiv demann yo →</Link>
          </article>
          <article className="card dashboard-stat">
            <span className="dashboard-card-label">RETRÈ AN ATANT</span>
            <strong>{pendingWithdrawals}</strong>
            <Link href="/historique">Swiv retrè yo →</Link>
          </article>
        </section>

        <section className="dashboard-section">
          <div className="dashboard-section-heading">
            <div><span className="eyebrow">AKSYON RAPID</span><h2>Ki sa ou vle fè?</h2></div>
          </div>
          <div className="dashboard-actions">
            <Link className="dashboard-action" href="/plans/nouveau"><span>🎯</span><strong>Kreye yon plan</strong><small>Fikse yon objektif ekonomi</small></Link>
            <Link className="dashboard-action" href="/depots/nouveau"><span>＋</span><strong>Fè yon depo</strong><small>Soumèt yon demann depo</small></Link>
            <Link className="dashboard-action" href="/retraits/nouveau"><span>↗</span><strong>Mande retrè</strong><small>Konsilte kondisyon ak frè</small></Link>
            <Link className="dashboard-action" href="/kontwol"><span>▥</span><strong>Kontwòl finansye</strong><small>Swiv bidjè ak depans</small></Link>
          </div>
        </section>

        <section className="dashboard-section">
          <div className="dashboard-section-heading">
            <div><span className="eyebrow">OBJEKTIF OU YO</span><h2>Plan ekonomi mwen yo</h2></div>
            <Link href="/plans/nouveau">+ Nouvo plan</Link>
          </div>
          {!plans?.length ? (
            <div className="empty">Ou poko kreye plan ekonomi. <Link href="/plans/nouveau">Kreye premye plan ou</Link>.</div>
          ) : (
            <div className="dashboard-plans">
              {plans.map(plan => {
                const progress = plan.has_goal && Number(plan.goal_amount) > 0 ? Math.min(100, Number(plan.balance) / Number(plan.goal_amount) * 100) : 0;
                return (
                  <article className="card dashboard-plan-card" key={plan.plan_id}>
                    <div className="dashboard-plan-top"><h3>{plan.title}</h3><span className="pill">{statusLabel(plan.status)}</span></div>
                    <strong className="dashboard-plan-balance">{money(plan.balance)}</strong>
                    <p className="muted small">Balans disponib: {money(plan.available_balance)}</p>
                    {plan.has_goal && <>
                      <div className="progress"><span style={{ width: `${progress}%` }} /></div>
                      <p className="small muted">Objektif: {money(plan.goal_amount)} · {progress.toFixed(0)}%</p>
                    </>}
                    <Link className="button secondary" href="/depots/nouveau">Ajoute ekonomi</Link>
                  </article>
                );
              })}
            </div>
          )}
        </section>

        <section className="dashboard-lower-grid">
          <div className="dashboard-section">
            <div className="dashboard-section-heading"><div><span className="eyebrow">KONT AKTIFITE</span><h2>Dènye mouvman</h2></div><Link href="/historique">Tout istorik →</Link></div>
            <div className="card table-wrap">
              {activities.length ? (
                <table><thead><tr><th>Kalite</th><th>Montan</th><th>Dat</th><th>Estati</th></tr></thead>
                  <tbody>{activities.map(row => <tr key={`${row.type}-${row.id}`}><td>{row.type}</td><td>{money(row.amount)}</td><td>{new Date(row.created_at).toLocaleDateString('fr-HT')}</td><td><span className="pill">{statusLabel(row.status)}</span></td></tr>)}</tbody>
                </table>
              ) : <p className="muted">Pa gen aktivite pou kounye a.</p>}
            </div>
          </div>
          <aside className="dashboard-section dashboard-help-card">
            <span className="eyebrow">ASISTANS</span><h2>Bezwen èd?</h2>
            <p className="muted">Jwenn repons sou kont ou, sekirite ak fason pou itilize KANÈ SA.</p>
            <Link className="button" href="/sipo">Kontakte sipò</Link>
            <Link className="dashboard-text-link" href="/konsèy-finansye">Li konsèy finansye →</Link>
            <Link className="dashboard-text-link" href="/notifikasyon">Gade notifikasyon →</Link>
          </aside>
        </section>

        <div className="dashboard-notifications"><EnableNotifications /></div>
      </main>
    </>
  );
}
