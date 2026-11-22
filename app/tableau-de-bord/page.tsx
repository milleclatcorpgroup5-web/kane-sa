import Link from 'next/link';
import { Header } from '@/components/header';
import { Notice } from '@/components/notice';
import { money, statusLabel } from '@/lib/format';
import { requireUser } from '@/lib/auth';
import { EnableNotifications } from '@/components/enable-notifications';

export const dynamic = 'force-dynamic';
export default async function DashboardPage(){
  const {supabase,user}=await requireUser();
  const [{data:profile},{data:plans},{data:deposits},{data:withdrawals},{data:systemControls}] = await Promise.all([
    supabase.from('profiles').select('full_name,role').eq('id',user.id).maybeSingle(),
    supabase.from('plan_balances').select('*').eq('user_id',user.id).order('plan_id'),
    supabase.from('deposit_requests').select('id,amount,status,created_at,method').eq('user_id',user.id).order('created_at',{ascending:false}).limit(5),
    supabase.from('withdrawal_requests').select('id,gross_amount,net_amount,status,created_at,kind').eq('user_id',user.id).order('created_at',{ascending:false}).limit(5),
    supabase.from('system_controls').select('deposits_enabled,withdrawal_requests_enabled,public_notice').eq('id',1).maybeSingle(),
  ]);
  const total=(plans??[]).reduce((sum,p)=>sum+Number(p.balance||0),0);
  return <><Header signedIn/><main className="container page"><div className="section-title"><div><span className="eyebrow">Espas pèsonèl</span><h1>Bonjou, {profile?.full_name||'kliyan'} 👋</h1><p className="muted">Men yon rezime ekonomi ou yo.</p></div><span className="pill">Wòl: {statusLabel(profile?.role||'kliyan')}</span></div>
    <Notice tone="warning">Sèl depo administrasyon an verifye ki konte nan balans lan. Demann depo pa vle di lajan an deja antre.</Notice>{systemControls?.public_notice&&<Notice tone="info">{systemControls.public_notice}</Notice>}{systemControls&&(!systemControls.deposits_enabled||!systemControls.withdrawal_requests_enabled)&&<Notice tone="warning">Gen yon fonksyon ki sispann tanporèman: {systemControls.deposits_enabled?"depo yo disponib":"nouvo demann depo yo sispann"}; {systemControls.withdrawal_requests_enabled?"nouvo retrè yo disponib":"nouvo demann retrè yo sispann"}.</Notice>}
    <section className="grid"><article className="card"><div className="metric-label">Balans total konfime</div><div className="metric">{money(total)}</div><p className="muted small">Total sou tout plan ou yo.</p></article><article className="card"><div className="metric-label">Plan ekonomi</div><div className="metric">{plans?.length??0}</div><Link href="/plans/nouveau">Kreye yon nouvo plan →</Link></article><article className="card"><div className="metric-label">Depo an atant</div><div className="metric">{deposits?.filter(d=>d.status==='pending').length??0}</div><Link href="/depots/nouveau">Fè yon demann depo →</Link></article><article className="card"><div className="metric-label">Retrè an atant</div><div className="metric">{withdrawals?.filter(w=>w.status==='pending'||w.status==='approved').length??0}</div><Link href="/retraits/nouveau">Mande yon retrè →</Link></article></section>
    <div className="section-title"><h2>Plan ekonomi mwen yo</h2><Link href="/plans/nouveau">+ Nouvo plan</Link></div>
    {!plans?.length?<div className="empty">Ou poko kreye plan ekonomi. <Link href="/plans/nouveau">Kreye premye plan ou</Link>.</div>:<section className="grid">{plans.map(plan=>{const progress=plan.has_goal&&Number(plan.goal_amount)>0?Math.min(100,Number(plan.balance)/Number(plan.goal_amount)*100):0;return <article className="card" key={plan.plan_id}><h3>{plan.title}</h3><div className="metric">{money(plan.balance)}</div><p className="muted small">Balans disponib: {money(plan.available_balance)}</p>{plan.has_goal&&<><div className="progress"><span style={{width:`${progress}%`}}/></div><p className="small muted">Objektif: {money(plan.goal_amount)} · {progress.toFixed(0)}%</p></>}<span className="pill">{statusLabel(plan.status)}</span><div className="actions"><Link className="button" href="/depots/nouveau">Ajoute ekonomi</Link></div></article>})}</section>}
    <section className="card control-teaser"><div><h3>Kontwòl lajan mwen</h3><p className="muted small">Swiv depans, fikse bidjè epi wè analiz ekonomi ou.</p></div><div className="actions"><Link className="button" href="/kontwol">Louvri Kontwòl</Link><Link className="button secondary" href="/konsèy-finansye">Konsèy finansye</Link><Link className="button secondary" href="/notifikasyon">Notifikasyon</Link><Link className="button secondary" href="/sipo">Sant sipò</Link></div></section>
    <div style={{marginTop:20}}><EnableNotifications/></div>
    <div className="section-title"><h2>Dènye aktivite</h2><Link href="/historique">Tout istorik →</Link></div>
    <div className="card table-wrap"><table><thead><tr><th>Kalite</th><th>Montan</th><th>Dat</th><th>Estati</th></tr></thead><tbody>{[...(deposits??[]).map(d=>({...d,type:'Depo',amount:d.amount})),...(withdrawals??[]).map(w=>({...w,type:'Retrè',amount:w.gross_amount}))].sort((a,b)=>new Date(b.created_at).getTime()-new Date(a.created_at).getTime()).slice(0,8).map(row=><tr key={`${row.type}-${row.id}`}><td>{row.type}</td><td>{money(row.amount)}</td><td>{new Date(row.created_at).toLocaleDateString('fr-HT')}</td><td><span className="pill">{statusLabel(row.status)}</span></td></tr>)}</tbody></table>{!deposits?.length&&!withdrawals?.length&&<p className="muted">Pa gen aktivite pou kounye a.</p>}</div>
  </main></>;
}
