import Link from 'next/link';
import { Header } from '@/components/header';
import { Notice } from '@/components/notice';
import { ActionButton } from '@/components/compliance-client';
import { requireRole } from '@/lib/auth';
import { dateTime } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Konfòmite' };

export default async function CompliancePage() {
  const { supabase } = await requireRole(['admin']);
  const [{ data: gates }, { data: settings }, { data: kyc }, { data: flags }] = await Promise.all([
    supabase.from('go_live_gates').select('key,label,done,done_at').order('key'),
    supabase.from('compliance_settings').select('*').eq('id', 1).maybeSingle(),
    supabase.from('kyc_profiles').select('user_id,legal_name,date_of_birth,document_type,document_last4,submitted_at').eq('status', 'pending').order('submitted_at'),
    supabase.from('aml_flags').select('id,user_id,ref_type,reason,created_at').eq('status', 'open').order('created_at', { ascending: false }).limit(50),
  ]);
  return <><Header signedIn /><main className="container page">
    <div className="section-title"><div><span className="eyebrow">Zòn prive</span><h1>Konfòmite ak pòtay lansman</h1></div><Link href="/admin">← Admin</Link></div>
    <section className="card"><h2>Mòd finansye: FÈMEN</h2><p className="muted small">Limit KYC: {settings?.kyc_threshold} HTG · revizyon AML: {settings?.aml_review_amount} HTG · max {settings?.aml_max_requests_24h} demann/24h.</p><p className="small">Checklist pòtay yo: {gates?.filter((g) => g.done).length ?? 0}/{gates?.length ?? 0} make fini. Sa pa aktive peman.</p><Notice tone="warning">Mòd lajan reyèl la gen yon verrou teknik nan kòd ak bazdone v1.7.0-dev.0. Menm lè tout pòtay yo fini, pa gen bouton ki kapab aktive li. Ale nan <Link href="/admin/lajan-reel">Espas lajan reyèl</Link> pou wè eta provider yo.</Notice></section>
    <div className="section-title"><h2>Pòtay lansman</h2></div>
    <div className="card">{(gates ?? []).map((g) => <div className="tx-row" key={g.key}><div><b>{g.done ? '✔' : '○'} {g.label}</b>{g.done_at && <div className="small muted">{dateTime(g.done_at)}</div>}</div><ActionButton secondary body={{ action: 'gate', key: g.key, done: !g.done }} label={g.done ? 'Retire' : 'Make fini'} /></div>)}</div>
    <div className="section-title"><h2>KYC an atant ({kyc?.length ?? 0})</h2></div>
    <div className="card">{kyc?.length ? kyc.map((k) => <div className="tx-row" key={k.user_id}><div><b>{k.legal_name}</b><div className="small muted">{k.date_of_birth} · {k.document_type.toUpperCase()} …{k.document_last4}</div></div><div className="actions" style={{ marginTop: 0 }}><ActionButton body={{ action: 'kyc', user_id: k.user_id, decision: 'verified' }} label="Verifye" /><ActionButton secondary body={{ action: 'kyc', user_id: k.user_id, decision: 'rejected', note: 'Dokiman pa klè' }} label="Rejte" /></div></div>) : <p className="muted">Anyen pou revize.</p>}</div>
    <div className="section-title"><h2>Alèt AML ouvè ({flags?.length ?? 0})</h2></div>
    <div className="card">{flags?.length ? flags.map((f) => <div className="tx-row" key={f.id}><div><b>{f.reason === 'large_amount' ? 'Gwo montan' : 'Twòp demann nan 24h'}</b><div className="small muted">{f.ref_type} · {dateTime(f.created_at)} · {f.user_id.slice(0, 8)}</div></div><ActionButton secondary body={{ action: 'aml', id: f.id }} label="Make revize" /></div>) : <p className="muted">Pa gen alèt.</p>}</div>
  </main></>;
}
