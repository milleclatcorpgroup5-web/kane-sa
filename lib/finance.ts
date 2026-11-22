export const EXPENSE_CATEGORIES = { manje: 'Manje', transpo: 'Transpò', lekol: 'Lekòl', sante: 'Sante', kay: 'Kay', lot: 'Lòt' } as const;
export type ExpenseCategory = keyof typeof EXPENSE_CATEGORIES;
export type Tx = { kind: 'in' | 'out'; category: string; amount: number | string; occurred_on: string };

export const monthOf = (iso: string) => iso.slice(0, 7);
export function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1 + delta, 1)).toISOString().slice(0, 7);
}

export function monthSummary(txs: Tx[], month: string) {
  let income = 0, spent = 0;
  const byCategory: Record<string, number> = {};
  for (const t of txs) {
    if (monthOf(t.occurred_on) !== month) continue;
    const a = Number(t.amount);
    if (t.kind === 'in') income += a;
    else { spent += a; byCategory[t.category] = (byCategory[t.category] ?? 0) + a; }
  }
  return { income, spent, net: income - spent, byCategory };
}

/** Mwayèn depans sou n mwa anvan mwa a. */
export function avgSpend(txs: Tx[], month: string, n = 3): number {
  let total = 0;
  for (let i = 1; i <= n; i++) total += monthSummary(txs, shiftMonth(month, -i)).spent;
  return total / n;
}

/** Nòt 0-100: 40 pa to ekonomi (vize 20%), 30 pa respè bidjè, 30 pa fonn ijans (vize 3 mwa). */
export function healthScore(i: { income: number; spent: number; overBudget: number; budgetCount: number; savings: number; avgMonthlySpend: number }) {
  const rate = i.income > 0 ? (i.income - i.spent) / i.income : 0;
  const a = Math.min(40, Math.max(0, (rate / 0.2) * 40));
  const b = i.budgetCount ? 30 * (1 - i.overBudget / i.budgetCount) : 15;
  const cover = i.avgMonthlySpend > 0 ? i.savings / i.avgMonthlySpend : 0;
  const c = Math.min(30, (cover / 3) * 30);
  return { score: Math.round(a + b + c), coverMonths: cover, savingsRate: rate };
}
