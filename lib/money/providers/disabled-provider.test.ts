import { describe, expect, it } from 'vitest';
import { getMoneyProviderAdapter } from './disabled-provider';

describe('disabled provider adapter', () => {
  it('refize tout operasyon MonCash san apèl rezo', async () => {
    const adapter = getMoneyProviderAdapter('moncash');
    const results = await Promise.all([
      adapter.createDepositIntent({ requestId: 'req-1', amount: 500, currency: 'HTG', idempotencyKey: 'abcdefghijklmnop' }),
      adapter.verifyDeposit({ providerReference: 'ref-1' }),
      adapter.createPayout({ withdrawalId: 'wd-1', amount: 450, currency: 'HTG', idempotencyKey: 'qrstuvwxyzabcdef' }),
      adapter.verifyPayout({ providerReference: 'ref-2' }),
      adapter.verifyWebhook({ headers: new Headers(), rawBody: '{}' }),
    ]);
    expect(results.every((result) => result.ok === false && result.code === 'PROVIDER_DISABLED')).toBe(true);
  });

  it('ofri menm sekirite pou NatCash', async () => {
    const result = await getMoneyProviderAdapter('natcash').createPayout({
      withdrawalId: 'wd-2', amount: 100, currency: 'HTG', idempotencyKey: '1234567890abcdef',
    });
    expect(result.code).toBe('PROVIDER_DISABLED');
  });
});
