import { NextResponse } from 'next/server';
import { requireAdminApi } from '@/lib/supabase/admin-guard';
import { toCsv } from '@/lib/csv';

export async function GET(request: Request) {
  const auth = await requireAdminApi();
  if ('response' in auth) return auth.response;
  const url = new URL(request.url);
  const q = (url.searchParams.get('q') || '').trim().slice(0, 80).replace(/[%_]/g, '');
  const action = (url.searchParams.get('action') || '').trim().slice(0, 80);
  const entityType = (url.searchParams.get('entity_type') || '').trim().slice(0, 80);
  const actorId = (url.searchParams.get('actor_id') || '').trim();
  const from = url.searchParams.get('from') || '';
  const to = url.searchParams.get('to') || '';
  let query = auth.supabase.from('audit_logs').select('id,actor_id,action,entity_type,entity_id,metadata,created_at').order('created_at', { ascending: false }).limit(5000);
  if (q) query = query.ilike('action', `%${q}%`);
  if (action) query = query.eq('action', action);
  if (entityType) query = query.eq('entity_type', entityType);
  if (/^[0-9a-f-]{36}$/i.test(actorId)) query = query.eq('actor_id', actorId);
  if (/^\d{4}-\d{2}-\d{2}$/.test(from)) query = query.gte('created_at', `${from}T00:00:00.000Z`);
  if (/^\d{4}-\d{2}-\d{2}$/.test(to)) { const end = new Date(`${to}T00:00:00.000Z`); if (!Number.isNaN(end.getTime())) query = query.lt('created_at', new Date(end.getTime() + 86400000).toISOString()); }
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: 'Nou pa t kapab ekspòte audit logs yo.' }, { status: 500 });
  const csv = toCsv(['id', 'actor_id', 'action', 'entity_type', 'entity_id', 'metadata', 'created_at'],
    (data ?? []).map((row) => [row.id, row.actor_id, row.action, row.entity_type, row.entity_id, row.metadata, row.created_at]));
  return new NextResponse(`\uFEFF${csv}`, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': 'attachment; filename="kane-sa-audit-logs.csv"',
      'Cache-Control': 'no-store',
    },
  });
}
