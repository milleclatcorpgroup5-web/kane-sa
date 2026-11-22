import { z } from 'zod';
import { EXPENSE_CATEGORIES } from './finance';

const cats = Object.keys(EXPENSE_CATEGORIES) as [string, ...string[]];
export const transactionSchema = z.object({
  kind: z.enum(['in', 'out']),
  category: z.enum([...cats, 'revni'] as [string, ...string[]]),
  amount: z.coerce.number().positive().max(100_000_000),
  note: z.string().trim().max(80).optional(),
}).refine((v) => (v.kind === 'in' ? v.category === 'revni' : v.category !== 'revni'), { message: 'Kategori a pa koresponn ak kalite a.' });

export const budgetSchema = z.object({ category: z.enum(cats), monthly_limit: z.coerce.number().positive().max(100_000_000) });
