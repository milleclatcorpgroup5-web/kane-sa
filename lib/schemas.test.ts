import { describe, expect, it } from 'vitest';
import { transactionSchema } from './schemas';
import { complianceAction, kycSchema } from './schemas.kyc';

describe('schemas', () => {
  it('revni dwe gen kategori revni, depans pa dwe', () => {
    expect(transactionSchema.safeParse({ kind: 'in', category: 'revni', amount: 100 }).success).toBe(true);
    expect(transactionSchema.safeParse({ kind: 'in', category: 'manje', amount: 100 }).success).toBe(false);
    expect(transactionSchema.safeParse({ kind: 'out', category: 'revni', amount: 100 }).success).toBe(false);
  });
  it('rejte montan negatif ak twò gwo', () => {
    expect(transactionSchema.safeParse({ kind: 'out', category: 'manje', amount: -5 }).success).toBe(false);
    expect(transactionSchema.safeParse({ kind: 'out', category: 'manje', amount: 1e9 }).success).toBe(false);
  });
  it('KYC: 4 dènye karaktè egzak', () => {
    const ok = { legal_name: 'Jan Pyè', date_of_birth: '1990-01-01', address: 'Pòtoprens', document_type: 'cin', document_last4: 'A123' };
    expect(kycSchema.safeParse(ok).success).toBe(true);
    expect(kycSchema.safeParse({ ...ok, document_last4: '12345' }).success).toBe(false);
  });
  it('aksyon konfòmite enkonni rejte', () => {
    expect(complianceAction.safeParse({ action: 'drop' }).success).toBe(false);
  });
});
