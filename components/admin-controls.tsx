'use client';

import { useState } from 'react';

async function post(url: string, body: Record<string,string> = {}) {
  const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'Aksyon an echwe.');
}

export function AdminDepositControls({ id }: { id: string }) {
  const [busy,setBusy]=useState(false); const [message,setMessage]=useState('');
  async function run(action:'confirm'|'reject') { const reference=action==='confirm'?window.prompt('Mete referans tranzaksyon verifye a (si genyen):')||'':window.prompt('Rezon refi a (opsyonèl):')||''; if(action==='confirm'&&!window.confirm('Èske ou verifye tranzaksyon an sou sous ofisyèl la?'))return;setBusy(true);setMessage('');try{await post(`/api/admin/depots/${id}/${action==='confirm'?'confirmer':'refize'}`,action==='confirm'?{reference}:{note:reference});setMessage('Aksyon an fèt.');window.location.reload();}catch(e){setMessage(e instanceof Error?e.message:'Erè.');}finally{setBusy(false);} }
  return <div className="actions"><button className="button green" disabled={busy} onClick={()=>run('confirm')}>Konfime depo</button><button className="button secondary" disabled={busy} onClick={()=>run('reject')}>Refize</button>{message&&<span className="small">{message}</span>}</div>;
}

export function AdminWithdrawalControls({ id, status }: { id: string; status: string }) {
  const [busy,setBusy]=useState(false); const [message,setMessage]=useState('');
  async function review(decision:'approved'|'rejected') { const note=window.prompt('Nòt administratè (opsyonèl):')||'';setBusy(true);try{await post(`/api/admin/retraits/${id}/examiner`,{decision,note});window.location.reload();}catch(e){setMessage(e instanceof Error?e.message:'Erè.');}finally{setBusy(false);} }
  async function markPaid(){const reference=window.prompt('Antre referans peman an (obligatwa):');if(!reference)return;setBusy(true);try{await post(`/api/admin/retraits/${id}/payer`,{reference});window.location.reload();}catch(e){setMessage(e instanceof Error?e.message:'Erè.');}finally{setBusy(false);}}
  return <div className="actions">{status==='pending'&&<><button className="button green" disabled={busy} onClick={()=>review('approved')}>Apwouve</button><button className="button secondary" disabled={busy} onClick={()=>review('rejected')}>Refize</button></>}{status==='approved'&&<button className="button green" disabled={busy} onClick={markPaid}>Make kòm peye</button>}{message&&<span className="small">{message}</span>}</div>;
}
