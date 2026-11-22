import Link from 'next/link';
import { Header } from '@/components/header';
import { requireRole } from '@/lib/auth';
import { dateTime } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Sant Audit' };

type Params = Promise<{ q?: string; action?: string; entity_type?: string; actor_id?: string; from?: string; to?: string; page?: string }>;

function validDate(value?: string) {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value ? null : date;
}

export default async function AuditCenterPage({ searchParams }: { searchParams: Params }) {
  const { supabase } = await requireRole(['admin']);
  const params = await searchParams;
  const q = (params.q || '').trim().slice(0, 80);
  const action = (params.action || '').trim().slice(0, 80);
  const entityType = (params.entity_type || '').trim().slice(0, 80);
  const actorId = (params.actor_id || '').trim();
  const from = validDate(params.from);
  const to = validDate(params.to);
  const page = Math.max(1, Math.min(500, Number.parseInt(params.page || '1', 10) || 1));
  const pageSize = 50;

  let query = supabase.from('audit_logs').select('id,actor_id,action,entity_type,entity_id,metadata,created_at', { count: 'exact' }).order('created_at', { ascending: false });
  if (q) query = query.ilike('action', `%${q.replace(/[%_]/g, '')}%`);
  if (action) query = query.eq('action', action);
  if (entityType) query = query.eq('entity_type', entityType);
  if (/^[0-9a-f-]{36}$/i.test(actorId)) query = query.eq('actor_id', actorId);
  if (from) query = query.gte('created_at', from.toISOString());
  if (to) query = query.lt('created_at', new Date(to.getTime() + 86400000).toISOString());
  const { data: rows, count, error } = await query.range((page - 1) * pageSize, page * pageSize - 1);
  const actorIds = [...new Set((rows ?? []).map((row) => row.actor_id).filter((id): id is string => Boolean(id)))];
  const { data: actors } = actorIds.length ? await supabase.from('profiles').select('id,full_name,phone').in('id', actorIds) : { data: [] as Array<{ id: string; full_name: string; phone: string | null }> };
  const names = new Map((actors ?? []).map((actor) => [actor.id, actor]));
  const pageCount = Math.max(1, Math.ceil((count ?? 0) / pageSize));

  return <><Header signedIn /><main className="container page">
    <div className="section-title"><div><span className="eyebrow">Global Control · Sekirite</span><h1>Sant Audit</h1><p className="muted">Istwa aksyon privilejye ak operasyon ki kite tras nan bazdone a.</p></div><div className="actions"><Link className="button secondary" href={`/api/admin/audit/export?${new URLSearchParams({ q, action, entity_type: entityType, actor_id: actorId, from: params.from || '', to: params.to || '' }).toString()}`}>Ekspòte CSV</Link><Link href="/admin">← Admin</Link></div></div>
    <div className="notice notice-warning">Audit la se yon tras operasyonèl. Li pa ranplase log Cloudflare, Supabase Auth, founisè peman oswa yon sistèm SIEM ekstèn. Pa gen dwa modifye/siprime antre audit nan entèfas sa a.</div>
    <form method="get" className="card audit-filters">
      <div className="field"><label htmlFor="q">Chèche nan non aksyon an</label><input id="q" name="q" maxLength={80} defaultValue={q} placeholder="Egzanp: withdrawal_paid" /></div>
      <div className="field"><label htmlFor="action">Aksyon egzak</label><input id="action" name="action" maxLength={80} defaultValue={action} placeholder="Egzanp: settings_updated" /></div>
      <div className="field"><label htmlFor="entity_type">Kalite done</label><input id="entity_type" name="entity_type" maxLength={80} defaultValue={entityType} placeholder="Egzanp: withdrawal_request" /></div>
      <div className="field"><label htmlFor="actor_id">ID aktè (UUID)</label><input id="actor_id" name="actor_id" maxLength={36} defaultValue={actorId} /></div>
      <div className="field"><label htmlFor="from">Depi</label><input id="from" name="from" type="date" defaultValue={params.from || ''} /></div>
      <div className="field"><label htmlFor="to">Jiska</label><input id="to" name="to" type="date" defaultValue={params.to || ''} /></div>
      <div className="actions"><button className="button" type="submit">Aplike filtè</button><Link className="button secondary" href="/admin/audit">Efase filtè</Link></div>
    </form>
    <div className="section-title"><h2>{count ?? 0} antre audit</h2><span className="pill">Paj {page} / {pageCount}</span></div>
    <div className="card table-wrap">{error ? <p className="muted">Nou pa t kapab li audit logs yo. Verifye dwa admin ak koneksyon bazdone a.</p> : <table><thead><tr><th>Dat</th><th>Aktè</th><th>Aksyon</th><th>Kalite</th><th>ID done</th><th>Detay metadata</th></tr></thead><tbody>{(rows ?? []).map((row) => { const actor = row.actor_id ? names.get(row.actor_id) : null; return <tr key={row.id}><td>{dateTime(row.created_at)}</td><td>{actor?.full_name || (row.actor_id ? row.actor_id.slice(0, 8) : 'Sistèm')}<br /><span className="muted small">{actor?.phone || ''}</span></td><td><strong>{row.action}</strong></td><td>{row.entity_type}</td><td className="small">{row.entity_id || '—'}</td><td><code className="audit-metadata">{JSON.stringify(row.metadata ?? {})}</code></td></tr>; })}</tbody></table>}{!error && !rows?.length && <p className="muted">Pa gen antre ki koresponn ak filtè sa yo.</p>}</div>
    <div className="actions"><Link className={`button secondary ${page <= 1 ? 'is-disabled' : ''}`} aria-disabled={page <= 1} href={`/admin/audit?${new URLSearchParams({ q, action, entity_type: entityType, actor_id: actorId, from: params.from || '', to: params.to || '', page: String(Math.max(1, page - 1)) }).toString()}`}>← Anvan</Link><Link className={`button secondary ${page >= pageCount ? 'is-disabled' : ''}`} aria-disabled={page >= pageCount} href={`/admin/audit?${new URLSearchParams({ q, action, entity_type: entityType, actor_id: actorId, from: params.from || '', to: params.to || '', page: String(Math.min(pageCount, page + 1)) }).toString()}`}>Apre →</Link></div>
  </main></>;
}
