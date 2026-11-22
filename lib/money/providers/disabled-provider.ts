import type { MoneyProvider, MoneyProviderAdapter, ProviderOperationResult } from './types';

const disabledResult: ProviderOperationResult = Object.freeze({
  ok: false,
  code: 'PROVIDER_DISABLED',
  message: 'Kanal peman sa a poko aktive. Pa gen okenn mouvman lajan ki fèt.',
});

/** Adapter fail-closed: pa gen fetch, pa gen simulation, pa gen tranzaksyon reyèl. */
export class DisabledMoneyProvider implements MoneyProviderAdapter {
  constructor(readonly provider: MoneyProvider) {}

  async createDepositIntent(): Promise<ProviderOperationResult> { return disabledResult; }
  async verifyDeposit(): Promise<ProviderOperationResult> { return disabledResult; }
  async createPayout(): Promise<ProviderOperationResult> { return disabledResult; }
  async verifyPayout(): Promise<ProviderOperationResult> { return disabledResult; }
  async verifyWebhook(): Promise<ProviderOperationResult> { return disabledResult; }
}

export function getMoneyProviderAdapter(provider: MoneyProvider): MoneyProviderAdapter {
  return new DisabledMoneyProvider(provider);
}
