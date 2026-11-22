import { NextResponse } from 'next/server';
import type { MoneyProvider } from '@/lib/money/providers/types';
import { getMoneyRailFlags } from '@/lib/money/feature-flags';

const providers = new Set<MoneyProvider>(['moncash', 'natcash', 'bank']);
type Context = { params: Promise<{ provider: string }> };

export async function POST(_request: Request, context: Context) {
  const { provider } = await context.params;
  if (!providers.has(provider as MoneyProvider)) {
    return NextResponse.json({ error: 'Provider sa a pa rekonèt.' }, { status: 404, headers: { 'Cache-Control': 'no-store' } });
  }
  return NextResponse.json({
    error: 'Webhook yo fèmen. KANÈ SA pa aksepte ni trete evènman peman nan vèsyon sa a.',
    code: 'WEBHOOKS_DISABLED',
    provider,
    realMoneyEnabled: getMoneyRailFlags().realMoneyEnabled,
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
