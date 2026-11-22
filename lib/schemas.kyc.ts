import { z } from 'zod';
export const kycSchema = z.object({
  legal_name: z.string().trim().min(3).max(120),
  date_of_birth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  address: z.string().trim().min(5).max(240),
  document_type: z.enum(['cin', 'passport', 'nif', 'permis']),
  document_last4: z.string().regex(/^[A-Za-z0-9]{4}$/),
});
export const complianceAction = z.discriminatedUnion('action', [
  z.object({ action: z.literal('gate'), key: z.string().max(40), done: z.boolean() }),
  z.object({ action: z.literal('live'), live: z.boolean() }),
  z.object({ action: z.literal('kyc'), user_id: z.string().uuid(), decision: z.enum(['verified', 'rejected']), note: z.string().max(300).optional() }),
  z.object({ action: z.literal('aml'), id: z.string().uuid() }),
]);
