import { Header } from '@/components/header';
import { requireUser } from '@/lib/auth';
import { buildFinancialInsights, type InsightPlan } from '@/lib/insights';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Konsèy finansye' };

export default async function FinancialInsightsPage() {
  const { supabase, user } = await requireUser();
  const [{ data: planRows }, { data: balances }] = await Promise.all([
    supabase.from('savings_plans').select('id,title,has_goal,goal_amount,planned_contribution,frequency,status').eq('user_id', user.id),
    supabase.from('plan_balances').select('plan_id,balance,available_balance').eq('user_id', user.id),
  ]);
  const balanceMap = new Map((balances ?? []).map((row) => [row.plan_id, row]));
  const plans = (planRows ?? []).map((plan) => {
    const balance = balanceMap.get(plan.id);
    return {
      plan_id: plan.id, title: plan.title, has_goal: plan.has_goal, goal_amount: plan.goal_amount,
      balance: Number(balance?.balance ?? 0), available_balance: Number(balance?.available_balance ?? 0),
      planned_contribution: plan.planned_contribution, frequency: plan.frequency, status: plan.status,
    };
  }) as InsightPlan[];
  const insights = buildFinancialInsights(plans);
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Planifikasyon pèsonèl</span><h1>Konsèy finansye</h1><p className="muted">Analiz otomatik ki baze sou plan ak balans konfime ou yo. Sa pa yon konsèy finansye pwofesyonèl.</p></div><span className="pill">Analiz prive</span></div><div className="notice notice-info">Modil sa a sèvi ak règ kalkil transparan, san li pa voye done finansye ou bay yon sèvis AI ekstèn. Estimasyon yo pa garanti rezilta.</div><div className="grid">{insights.map((item) => <article className="card insight-card" key={item.id}><span className={`insight-mark ${item.tone}`}>{item.tone === 'success' ? '✓' : item.tone === 'warning' ? '!' : 'i'}</span><h2>{item.title}</h2><p>{item.message}</p>{item.progress !== undefined && <div className="progress"><span style={{ width: `${item.progress}%` }} /></div>}</article>)}</div></main></>;
}
