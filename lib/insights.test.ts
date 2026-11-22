import { describe, expect, it } from 'vitest';
import { buildFinancialInsights, type InsightPlan } from './insights';

const base: InsightPlan = {
  plan_id: 'plan-1', title: 'Lekòl', has_goal: true, goal_amount: 12000,
  balance: 3000, available_balance: 3000, planned_contribution: 1000,
  frequency: 'monthly', status: 'active',
};

describe('buildFinancialInsights', () => {
  it('propose yon premye etap lè pa gen plan', () => {
    expect(buildFinancialInsights([])[0]?.id).toBe('start');
  });
  it('kalkile yon estimasyon ki make kòm estimasyon', () => {
    const result = buildFinancialInsights([base]);
    expect(result.some((item) => item.message.includes('9 mwa') && item.message.includes('estimasyon'))).toBe(true);
  });
  it('idantifye yon objektif ki rive', () => {
    const result = buildFinancialInsights([{ ...base, balance: 12000 }]);
    expect(result.some((item) => item.id === 'plan-1-reached')).toBe(true);
  });
  it('pa fè forecast pou plan san kontribisyon', () => {
    const result = buildFinancialInsights([{ ...base, planned_contribution: null }]);
    expect(result.some((item) => item.id === 'plan-1-pace')).toBe(true);
  });
});
