'use client';

import { useState } from 'react';
import { enablePushNotifications } from '@/lib/firebase/push';

export function EnableNotifications() {
  const [message,setMessage]=useState(''); const [busy,setBusy]=useState(false);
  async function enable(){setBusy(true);setMessage('');try{const token=await enablePushNotifications();const response=await fetch('/api/notifications/token',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token,platform:'web'})});const data=await response.json();if(!response.ok)throw new Error(data.error||'Nou pa rive anrejistre notifikasyon an.');setMessage('Notifikasyon aktive sou aparèy sa a.');}catch(error){setMessage(error instanceof Error?error.message:'Notifikasyon pa aktive.');}finally{setBusy(false);}}
  return <section className="card"><h3>Notifikasyon</h3><p className="muted small">Aktive notifikasyon navigatè a pou resevwa alèt lè sistèm nan voye yo. Firebase dwe konfigire anvan.</p><button className="button secondary" onClick={enable} disabled={busy}>{busy?'Ap aktive…':'Aktive notifikasyon'}</button>{message&&<p className="small muted">{message}</p>}</section>;
}
