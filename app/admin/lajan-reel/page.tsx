import Link from 'next/link';
import { Header } from '@/components/header';
import { Notice } from '@/components/notice';
import { requireRole } from '@/lib/auth';
import { dateTime } from '@/lib/format';

export const dynamic = 'force-dynamic';

const providerLabel: Record<string, string> = {
  moncash: 'MonCash',
  natcash: 'NatCash',
  bank: 'Bank / patnè bankè',
};

export default async function AdminRealMoneyPage() {
  const { supabase } = await requireRole(['admin']);
  const [controlsResult, providersResult, intentsResult, payoutsResult, webhooksResult, batchesResult, reconciliationRunsResult, reconciliationIssuesResult] = await Promise.all([
    supabase.from('money_rail_controls').select('*').eq('id', 1).maybeSingle(),
    supabase.from('money_provider_accounts').select('*').order('provider'),
    supabase.from('payment_intents').select('id', { count: 'exact', head: true }),
    supabase.from('payout_attempts').select('id', { count: 'exact', head: true }),
    supabase.from('provider_webhook_inbox').select('id', { count: 'exact', head: true }),
    supabase.from('provider_settlement_batches').select('id', { count: 'exact', head: true }),
    supabase.from('provider_reconciliation_runs').select('id', { count: 'exact', head: true }),
    supabase.from('provider_reconciliation_issues').select('id', { count: 'exact', head: true }),
  ]);

  const dataReady = !controlsResult.error && !providersResult.error && !intentsResult.error && !payoutsResult.error && !webhooksResult.error && !batchesResult.error && !reconciliationRunsResult.error && !reconciliationIssuesResult.error;
  const controls = controlsResult.data;
  const providers = providersResult.data ?? [];
  const counts = [intentsResult.count ?? 0, payoutsResult.count ?? 0, webhooksResult.count ?? 0, batchesResult.count ?? 0, reconciliationRunsResult.count ?? 0, reconciliationIssuesResult.count ?? 0];

  return <>
    <Header signedIn />
    <main className="container page">
      <div className="admin-header">
        <div>
          <span className="eyebrow">Super Admin · Finans</span>
          <h1>Espas lajan reyèl</h1>
          <p className="muted">Enfrastrikti peman provider la prepare pou devlopman; okenn koneksyon otomatik MonCash/NatCash/bank pa aktive.</p>
        </div>
        <div className="actions" style={{ marginTop: 0 }}>
          <Link className="button secondary" href="/admin">Retounen nan Admin</Link>
          <span className="pill">Read-only · LOCKED</span>
        </div>
      </div>

      <Notice tone="warning">
        KONEKSYON PROVIDER FÈMEN. Depo otomatik, payout otomatik, sandbox ak webhook yo dezaktive nan kòd ak bazdone a. Demann depo/retrè manyèl ki deja nan MVP a se yon lòt workflow; pa sèvi avè l pou kliyan reyèl anvan tout pòtay legal, sekirite ak finansye yo pase.
      </Notice>

      {!dataReady && <Notice tone="warning">Bazdone a poko gen migration 0008 oswa kèk tab pa aksesib. Aplike migration 0008 sou pwojè Supabase Development anvan ou itilize paj sa a.</Notice>}

      <section className="grid">
        <article className="card">
          <div className="metric-label">Mouvman lajan reyèl</div>
          <div className="metric" style={{ color: 'var(--danger, #a33)' }}>DEZAKTIVE</div>
          <p className="muted small">Verrou: {controls?.kill_switch ? 'ON' : '—'}</p>
        </article>
        <article className="card"><div className="metric-label">Koneksyon depo provider</div><div className="metric">FÈMEN</div><p className="muted small">Inbound pa ouvè</p></article>
        <article className="card"><div className="metric-label">Koneksyon payout provider</div><div className="metric">FÈMEN</div><p className="muted small">Outbound pa ouvè</p></article>
        <article className="card"><div className="metric-label">Sandbox</div><div className="metric">FÈMEN</div><p className="muted small">Pa gen apèl API tès otomatik</p></article>
      </section>

      <div className="section-title"><h2>Eta provider yo</h2></div>
      <div className="grid">
        {providers.map((provider) => <article className="card" key={provider.provider}>
          <div className="actions" style={{ justifyContent: 'space-between', marginTop: 0 }}>
            <h3>{providerLabel[provider.provider] ?? provider.display_name}</h3>
            <span className="pill">DEZAKTIVE</span>
          </div>
          <p className="muted small">Anviwònman: {provider.environment}</p>
          <ul className="small" style={{ paddingLeft: 18, lineHeight: 1.8 }}>
            <li>Kle/credentials: pa konfigire</li>
            <li>Depo (inbound): fèmen</li>
            <li>Payout (outbound): fèmen</li>
            <li>Webhook signature: pa verifye</li>
            <li>Sandbox: poko teste</li>
          </ul>
          <p className="muted small">Dènye verifikasyon: {provider.last_checked_at ? dateTime(provider.last_checked_at) : 'Pa janm'}</p>
        </article>)}
        {providers.length === 0 && <article className="card"><p className="muted">Pa gen provider anrejistre. Verifye migration 0008.</p></article>}
      </div>

      <div className="section-title"><h2>Espas tranzaksyon teknik</h2></div>
      <section className="grid">
        <article className="card"><div className="metric-label">Payment intents staged</div><div className="metric">{counts[0]}</div><p className="muted small">Se pa yon depo konfime; pa gen ledger credit.</p></article>
        <article className="card"><div className="metric-label">Payout attempts staged</div><div className="metric">{counts[1]}</div><p className="muted small">Se pa yon payout fèt; pa gen lajan ki voye.</p></article>
        <article className="card"><div className="metric-label">Webhook ki bloke</div><div className="metric">{counts[2]}</div><p className="muted small">Pa gen evènman ki trete.</p></article>
        <article className="card"><div className="metric-label">Deklarasyon provider</div><div className="metric">{counts[3]}</div><p className="muted small">Rekonsilyasyon ekstèn poko aktive.</p></article>
        <article className="card"><div className="metric-label">Run rekonsilyasyon staged</div><div className="metric">{counts[4]}</div><p className="muted small">Pa gen okenn run ki egzekite.</p></article>
        <article className="card"><div className="metric-label">Eksepsyon rekonsilyasyon</div><div className="metric">{counts[5]}</div><p className="muted small">Pa gen okenn eksepsyon trete.</p></article>
      </section>

      <div className="section-title"><h2>Verrou ak kondisyon</h2></div>
      <div className="card">
        <p><strong>Rezon verrou:</strong> {controls?.locked_reason ?? 'Migration 0008 poko disponib.'}</p>
        <p className="muted small">Dènye chanjman bazdone: {controls?.updated_at ? dateTime(controls.updated_at) : '—'}</p>
        <h3>Sa ki deja prepare nan kòd la</h3>
        <ul style={{ paddingLeft: 20, lineHeight: 1.8 }}>
          <li>Estrikti provider MonCash, NatCash ak bank, san sekrè API.</li>
          <li>Payment intents ak idempotency pou depo.</li>
          <li>Payout attempts apa ak idempotency pou retrè.</li>
          <li>Webhook inbox ki pa konsève payload HTTP brit.</li>
          <li>Espas deklarasyon provider, run rekonsilyasyon ak lis eksepsyon.</li>
          <li>API prepare ki reponn 503 pandan mouvman lajan fèmen.</li>
          <li>Verrou SQL ki anpeche admin aktive ansyen `live_mode` la.</li>
        </ul>
      </div>

      <div className="section-title"><h2>Prensip kontablite</h2></div>
      <div className="card">
        <p>Yon demann depo pa yon depo resevwa. Yon retrè ki gen estati <code>approved</code> se sèlman otorizasyon entèn; se pa yon payout. Yon demann pa dwe pase nan <code>paid</code> san prèv egzekisyon verifye ak rekonsilyasyon.</p>
        <p className="muted small">Montan yo se HTG nan estrikti aktyèl la. Pa gen balans bank/provider ki konekte nan paj sa a.</p>
      </div>
    </main>
  </>;
}
