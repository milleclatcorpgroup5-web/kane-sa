import { describe, expect, it } from 'vitest';
import { getMoneyRailFlags, isProviderExecutionEnabled, isRealMoneyEnabled } from './feature-flags';

describe('money rail hard lock', () => {
  it('kenbe tout mòd tranzaksyon dezaktive', () => {
    expect(getMoneyRailFlags()).toEqual({
      realMoneyEnabled: false,
      inboundEnabled: false,
      outboundEnabled: false,
      sandboxEnabled: false,
      killSwitch: true,
      release: 'v1.7.0-dev.0',
    });
    expect(isRealMoneyEnabled()).toBe(false);
    expect(isProviderExecutionEnabled()).toBe(false);
  });
});
