import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { getMoneyRailFlags } from '@/lib/money/feature-flags';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;

  const [controls, providers, intents, payouts, webhooks, batches, reconciliationRuns, reconciliationIssues] = await Promise.all([
    auth.supabase.from('money_rail_controls').select('*').eq('id', 1).maybeSingle(),
    auth.supabase.from('money_provider_accounts').select('provider,display_name,enabled,environment,credentials_present,sandbox_verified,live_verified,inbound_enabled,outbound_enabled,webhook_url_configured,webhook_signature_verified,last_checked_at').order('provider'),
    auth.supabase.from('payment_intents').select('id', { count: 'exact', head: true }),
    auth.supabase.from('payout_attempts').select('id', { count: 'exact', head: true }),
    auth.supabase.from('provider_webhook_inbox').select('id', { count: 'exact', head: true }),
    auth.supabase.from('provider_settlement_batches').select('id', { count: 'exact', head: true }),
    auth.supabase.from('provider_reconciliation_runs').select('id', { count: 'exact', head: true }),
    auth.supabase.from('provider_reconciliation_issues').select('id', { count: 'exact', head: true }),
  ]);

  const queryErrors = [controls.error, providers.error, intents.error, payouts.error, webhooks.error, batches.error, reconciliationRuns.error, reconciliationIssues.error].filter(Boolean);
  if (queryErrors.length) {
    return NextResponse.json({ error: 'Estati espas peman an pa disponib.' }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }

  return NextResponse.json({
    flags: getMoneyRailFlags(),
    database: controls.data,
    providers: providers.data ?? [],
    stagedRecords: {
      paymentIntents: intents.count ?? 0,
      payoutAttempts: payouts.count ?? 0,
      webhookEvents: webhooks.count ?? 0,
      settlementBatches: batches.count ?? 0,
      reconciliationRuns: reconciliationRuns.count ?? 0,
      reconciliationIssues: reconciliationIssues.count ?? 0,
    },
    note: 'Estati sa a se preparasyon teknik. Li pa montre lajan reyèl oswa yon balans nan provider.',
  }, { headers: { 'Cache-Control': 'no-store' } });
}
