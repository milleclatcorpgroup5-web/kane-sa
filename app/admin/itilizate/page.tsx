import Link from 'next/link';
import { Header } from '@/components/header';
import { KanesaSelect, RoleSelect } from '@/components/admin-users';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Itilizatè ak Kanèsa' };

export default async function AdminUsersPage() {
  const { supabase, user } = await requireRole(['admin']);
  const [{ data: users }, { data: plans }, { data: checks }] = await Promise.all([
    supabase.from('profiles').select('id,full_name,phone,role').order('created_at', { ascending: false }).limit(200),
    supabase.from('savings_plans').select('id,title,user_id,kanesa_id').order('created_at', { ascending: false }).limit(200),
    supabase.from('integrity_checks').select('check_name,violations'),
  ]);
  const names = new Map((users ?? []).map((u) => [u.id, u.full_name]));
  const kanesas = (users ?? []).filter((u) => u.role === 'kanesa').map((u) => ({ id: u.id, name: u.full_name }));
  return <><Header signedIn /><main className="container page">
    <div className="section-title"><div><span className="eyebrow">Zòn prive</span><h1>Itilizatè ak Kanèsa</h1></div><Link href="/admin">← Tounen nan admin</Link></div>
    <section className="card"><h2>Kontwòl entegrite</h2>{(checks ?? []).map((c) => <p key={c.check_name}>{c.violations === 0 ? '✔' : '✘'} {c.check_name}: <b>{c.violations}</b> vyolasyon</p>)}</section>
    <div className="section-title"><h2>Itilizatè</h2></div>
    <div className="card table-wrap"><table><thead><tr><th>Non</th><th>Telefòn</th><th>Wòl</th></tr></thead><tbody>{(users ?? []).map((u) => <tr key={u.id}><td>{u.full_name}</td><td>{u.phone ?? '—'}</td><td>{u.id === user.id ? 'Ou menm (admin)' : <RoleSelect id={u.id} role={u.role} />}</td></tr>)}</tbody></table></div>
    <div className="section-title"><h2>Plan ak Kanèsa asiyen</h2></div>
    <div className="card table-wrap"><table><thead><tr><th>Plan</th><th>Pwopriyetè</th><th>Kanèsa</th></tr></thead><tbody>{(plans ?? []).map((p) => <tr key={p.id}><td>{p.title}</td><td>{names.get(p.user_id) ?? '—'}</td><td><KanesaSelect planId={p.id} current={p.kanesa_id} options={kanesas} /></td></tr>)}</tbody></table></div>
  </main></>;
}
