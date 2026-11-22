import { Header } from '@/components/header';
import { BudgetInput, DeleteTx, TxForm } from '@/components/kontwol-client';
import { requireUser } from '@/lib/auth';
import { avgSpend, EXPENSE_CATEGORIES, healthScore, monthSummary, shiftMonth } from '@/lib/finance';
import { money } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Kontwòl lajan' };

export default async function ControlPage() {
  const { supabase, user } = await requireUser();
  const month = new Date().toISOString().slice(0, 7);
  const [{ data: txs }, { data: buds }, { data: plans }] = await Promise.all([
    supabase.from('transactions').select('id,kind,category,amount,note,occurred_on').eq('user_id', user.id).gte('occurred_on', `${shiftMonth(month, -3)}-01`).order('occurred_on', { ascending: false }).limit(500),
    supabase.from('budgets').select('category,monthly_limit').eq('user_id', user.id),
    supabase.from('plan_balances').select('balance').eq('user_id', user.id),
  ]);
  const list = txs ?? [];
  const limits = Object.fromEntries((buds ?? []).map((b) => [b.category, Number(b.monthly_limit)]));
  const s = monthSummary(list, month);
  const cats = Object.keys(EXPENSE_CATEGORIES) as (keyof typeof EXPENSE_CATEGORIES)[];
  const over = cats.filter((c) => limits[c] && (s.byCategory[c] ?? 0) > limits[c]);
  const savings = (plans ?? []).reduce((t, p) => t + Number(p.balance || 0), 0);
  const h = healthScore({ income: s.income, spent: s.spent, overBudget: over.length, budgetCount: Object.keys(limits).length, savings, avgMonthlySpend: avgSpend(list, month) });
  const tips = [
    h.savingsRate < 0.2 && s.income > 0 ? `Eseye mete 20% revni w sou kote (${money(s.income * 0.2)}).` : '',
    over.length ? `Ou depase bidjè: ${over.map((c) => EXPENSE_CATEGORIES[c]).join(', ')}.` : '',
    h.coverMonths < 3 ? `Ekonomi ou kouvri ${h.coverMonths.toFixed(1)} mwa depans. Vize 3 mwa.` : '',
  ].filter(Boolean);
  return <><Header signedIn /><main className="container page">
    <div className="section-title"><div><span className="eyebrow">Kontwòl</span><h1>Lajan mwen, tout kote</h1></div></div>
    <section className="grid">
      <article className="card health"><div className="ring" style={{ ['--p' as string]: h.score }}><span>{h.score}</span></div><div><h3>Sante finansye</h3>{tips.length ? tips.map((t) => <p className="small muted" key={t}>{t}</p>) : <p className="small muted">Ou sou bon chemen. Kontinye konsa.</p>}</div></article>
      <article className="card"><div className="metric-label">Revni mwa a</div><div className="metric">{money(s.income)}</div></article>
      <article className="card"><div className="metric-label">Depans mwa a</div><div className="metric">{money(s.spent)}</div></article>
      <article className="card"><div className="metric-label">Rete</div><div className="metric" style={{ color: s.net < 0 ? '#b3261e' : undefined }}>{money(s.net)}</div></article>
    </section>
    <div className="two-col" style={{ marginTop: 20 }}>
      <section className="card"><h2>Bidjè mwa a</h2>{cats.map((c) => { const sp = s.byCategory[c] ?? 0, l = limits[c] ?? 0, p = l ? Math.min(100, (sp / l) * 100) : 0; return <div className="budget-row" key={c}><div><b>{EXPENSE_CATEGORIES[c]}</b><div className={`progress${sp > l && l ? ' over' : ''}`}><span style={{ width: `${p}%` }} /></div><span className="small muted">{money(sp)}{l ? ` sou ${money(l)}` : ' · pa gen limit'}</span></div><BudgetInput category={c} limit={l} /></div>; })}</section>
      <section className="card"><h2>Nouvo tranzaksyon</h2><TxForm /></section>
    </div>
    <div className="section-title"><h2>Dènye tranzaksyon</h2></div>
    <div className="card">{list.length ? list.slice(0, 12).map((t) => <div className="tx-row" key={t.id}><div><b>{t.note || (t.kind === 'in' ? 'Revni' : EXPENSE_CATEGORIES[t.category as keyof typeof EXPENSE_CATEGORIES] ?? t.category)}</b><div className="small muted">{t.occurred_on}</div></div><div><b style={{ color: t.kind === 'in' ? 'var(--green)' : undefined }}>{t.kind === 'in' ? '+' : '−'}{money(t.amount)}</b> <DeleteTx id={t.id} /></div></div>) : <div className="empty">Pa gen tranzaksyon ankò. Anrejistre premye a.</div>}</div>
  </main></>;
}
