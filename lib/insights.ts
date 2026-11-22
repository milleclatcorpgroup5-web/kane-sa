export type InsightPlan = {
  plan_id: string;
  title: string;
  has_goal: boolean;
  goal_amount: number | null;
  balance: number;
  available_balance: number;
  planned_contribution: number | null;
  frequency: 'daily' | 'weekly' | 'monthly' | 'flexible';
  status: 'active' | 'paused' | 'closed';
};

export type FinancialInsight = {
  id: string;
  tone: 'info' | 'success' | 'warning';
  title: string;
  message: string;
  progress?: number;
};

function monthlyContribution(amount: number | null, frequency: InsightPlan['frequency']): number {
  if (!amount || amount <= 0) return 0;
  switch (frequency) {
    case 'daily': return amount * 30;
    case 'weekly': return amount * 52 / 12;
    case 'monthly': return amount;
    default: return 0;
  }
}

export function buildFinancialInsights(plans: InsightPlan[]): FinancialInsight[] {
  if (!plans.length) return [{
    id: 'start', tone: 'info', title: 'Kòmanse ak yon plan',
    message: 'Kreye premye plan ekonomi ou epi fikse yon objektif ki reyalis pou sitiyasyon ou.',
  }];

  const insights: FinancialInsight[] = [];
  const activePlans = plans.filter((plan) => plan.status === 'active');
  const totalBalance = activePlans.reduce((total, plan) => total + Math.max(0, Number(plan.balance) || 0), 0);
  insights.push({
    id: 'total', tone: 'success', title: 'Ekonomi konfime ou',
    message: `Ou gen ${totalBalance.toLocaleString('fr-HT', { maximumFractionDigits: 2 })} HTG sou plan aktif ou yo. Se depo konfime sèlman ki antre nan total sa a.`,
  });

  for (const plan of activePlans) {
    if (!plan.has_goal || !plan.goal_amount || plan.goal_amount <= 0) continue;
    const balance = Math.max(0, Number(plan.balance) || 0);
    const goal = Number(plan.goal_amount);
    const progress = Math.min(100, Math.max(0, balance / goal * 100));
    const remaining = Math.max(0, goal - balance);
    if (remaining <= 0) {
      insights.push({ id: `${plan.plan_id}-reached`, tone: 'success', title: `Objektif « ${plan.title} » rive`, message: 'Balans konfime plan an egal oswa depase objektif ou te fikse a.', progress: 100 });
      continue;
    }
    const monthly = monthlyContribution(plan.planned_contribution, plan.frequency);
    if (monthly > 0) {
      const months = Math.ceil(remaining / monthly);
      insights.push({
        id: `${plan.plan_id}-forecast`, tone: 'info', title: `Pwogrè plan « ${plan.title} »`,
        message: `Ou rive nan ${progress.toFixed(0)}% objektif la. Si ou kenbe rit kontribisyon ou te planifye a, estimasyon an se anviwon ${months} mwa ankò. Se yon estimasyon, pa yon garanti.`,
        progress,
      });
    } else {
      insights.push({
        id: `${plan.plan_id}-pace`, tone: 'warning', title: `Fikse yon rit pou « ${plan.title} »`,
        message: `Ou rive nan ${progress.toFixed(0)}% objektif la. Ajoute yon kontribisyon prevwa ak frekans pou jwenn yon estimasyon tan ki pi itil.`,
        progress,
      });
    }
  }

  if (!insights.some((item) => item.id.includes('-forecast') || item.id.includes('-pace') || item.id.includes('-reached'))) {
    insights.push({ id: 'add-goal', tone: 'info', title: 'Fikse yon objektif', message: 'Ou kapab kreye yon plan ak objektif pou mezire pwogrè ou pi fasil.' });
  }
  return insights;
}
