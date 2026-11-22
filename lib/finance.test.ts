import { describe, expect, it } from 'vitest';
import { healthScore, monthSummary, shiftMonth } from './finance';

describe('finance', () => {
  it('shifts months across years', () => {
    expect(shiftMonth('2026-01', -1)).toBe('2025-12');
    expect(shiftMonth('2026-11', 2)).toBe('2027-01');
  });
  it('summarizes one month only', () => {
    const s = monthSummary([
      { kind: 'in', category: 'revni', amount: 1000, occurred_on: '2026-11-01' },
      { kind: 'out', category: 'manje', amount: '300', occurred_on: '2026-11-05' },
      { kind: 'out', category: 'manje', amount: 999, occurred_on: '2026-10-05' },
    ], '2026-11');
    expect(s).toEqual({ income: 1000, spent: 300, net: 700, byCategory: { manje: 300 } });
  });
  it('caps the score at 100 and never goes negative', () => {
    expect(healthScore({ income: 1000, spent: 100, overBudget: 0, budgetCount: 6, savings: 9000, avgMonthlySpend: 100 }).score).toBe(100);
    expect(healthScore({ income: 0, spent: 500, overBudget: 6, budgetCount: 6, savings: 0, avgMonthlySpend: 0 }).score).toBe(0);
  });
});
