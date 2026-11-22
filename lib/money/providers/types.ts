export type MoneyProvider = 'moncash' | 'natcash' | 'bank';
export type MoneyCurrency = 'HTG';

export type ProviderOperationResult = {
  ok: false;
  code: 'PROVIDER_DISABLED' | 'NOT_CONFIGURED';
  message: string;
};

/** Kontra adapter la defini pou entegrasyon ofisyèl pita; li pa gen okenn detay API envante. */
export interface MoneyProviderAdapter {
  readonly provider: MoneyProvider;
  createDepositIntent(input: { requestId: string; amount: number; currency: MoneyCurrency; idempotencyKey: string }): Promise<ProviderOperationResult>;
  verifyDeposit(input: { providerReference: string }): Promise<ProviderOperationResult>;
  createPayout(input: { withdrawalId: string; amount: number; currency: MoneyCurrency; idempotencyKey: string }): Promise<ProviderOperationResult>;
  verifyPayout(input: { providerReference: string }): Promise<ProviderOperationResult>;
  verifyWebhook(input: { headers: Headers; rawBody: string }): Promise<ProviderOperationResult>;
}
