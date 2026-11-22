'use client';

import { useState } from 'react';
import type { FormEvent } from 'react';

export function AdminSettings({ initial }: { initial: { normal_withdrawal_fee_percent:number; emergency_withdrawal_fee_percent:number; fees_enabled:boolean; maintenance_mode:boolean } }) {
  const [normal,setNormal]=useState(String(initial.normal_withdrawal_fee_percent));
  const [emergency,setEmergency]=useState(String(initial.emergency_withdrawal_fee_percent));
  const [fees,setFees]=useState(initial.fees_enabled);
  const [maintenance,setMaintenance]=useState(initial.maintenance_mode);
  const [message,setMessage]=useState(''); const [busy,setBusy]=useState(false);
  async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage('');try{const response=await fetch('/api/admin/settings',{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({normal_withdrawal_fee_percent:Number(normal),emergency_withdrawal_fee_percent:Number(emergency),fees_enabled:fees,maintenance_mode:maintenance})});const data=await response.json();if(!response.ok)throw new Error(data.error||'Pa rive sove paramèt yo.');setMessage('Paramèt yo sove.');}catch(err){setMessage(err instanceof Error?err.message:'Erè.');}finally{setBusy(false);}}
  return <form onSubmit={submit}><div className="field"><label htmlFor="normal-fee">Frè retrè nòmal (%)</label><input id="normal-fee" type="number" min="0" max="25" step="0.01" value={normal} onChange={e=>setNormal(e.target.value)}/></div><div className="field"><label htmlFor="emergency-fee">Frè retrè ijans (%)</label><input id="emergency-fee" type="number" min="0" max="25" step="0.01" value={emergency} onChange={e=>setEmergency(e.target.value)}/></div><label className="checkline"><input type="checkbox" checked={fees} onChange={e=>setFees(e.target.checked)}/> Aktive frè yo</label><label className="checkline"><input type="checkbox" checked={maintenance} onChange={e=>setMaintenance(e.target.checked)}/> Mòd antretyen (bloke aksyon ki modifye done pou kliyan; admin rete aktif)</label><button className="button" disabled={busy}>{busy?'Ap sove…':'Sove paramèt yo'}</button>{message&&<p className="small muted">{message}</p>}</form>;
}
