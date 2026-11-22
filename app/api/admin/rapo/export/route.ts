import { requireAdminApi } from '@/lib/supabase/admin-guard';

function csvCell(value: string | number) {
  const text = String(value);
  return `"${text.replaceAll('"', '""')}"`;
}

export async function GET() {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const [{ count: users }, { data: deposits }, { data: withdrawals }, { data: plans }] = await Promise.all([
    auth.supabase.from('profiles').select('id', { count: 'exact', head: true }),
    auth.supabase.from('deposits').select('amount,created_at').limit(10000),
    auth.supabase.from('withdrawal_requests').select('gross_amount,fee_amount,net_amount,status,created_at').limit(10000),
    auth.supabase.from('plan_balances').select('balance,available_balance').limit(10000),
  ]);
  const lines = [
    ['metrik', 'valè'],
    ['itilizate_total', users ?? 0],
    ['depo_konfime_total_htg', (deposits ?? []).reduce((sum, row) => sum + Number(row.amount), 0).toFixed(2)],
    ['retrè_paye_total_brit_htg', (withdrawals ?? []).filter((row) => row.status === 'paid').reduce((sum, row) => sum + Number(row.gross_amount), 0).toFixed(2)],
    ['frè_retre_paye_total_htg', (withdrawals ?? []).filter((row) => row.status === 'paid').reduce((sum, row) => sum + Number(row.fee_amount), 0).toFixed(2)],
    ['balans_plan_total_htg', (plans ?? []).reduce((sum, row) => sum + Number(row.balance), 0).toFixed(2)],
    ['balans_disponib_total_htg', (plans ?? []).reduce((sum, row) => sum + Number(row.available_balance), 0).toFixed(2)],
    ['dat_rapo', new Date().toISOString()],
  ];
  const content = '\uFEFF' + lines.map((line) => line.map(csvCell).join(',')).join('\r\n');
  return new Response(content, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': 'attachment; filename="kane-sa-rapo-global.csv"',
      'Cache-Control': 'no-store',
    },
  });
}
