'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Header } from '@/components/header';
import { createClient } from '@/lib/supabase/client';

export default function NewPasswordPage(){const [password,setPassword]=useState('');const [message,setMessage]=useState('');const [busy,setBusy]=useState(false);
async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage('');try{const supabase=createClient();const {error}=await supabase.auth.updateUser({password});if(error)throw error;setMessage('Modpas ou chanje. Ou kapab retounen konekte.');}catch(err){setMessage(err instanceof Error?err.message:'Lyen reset la ka ekspire. Mande yon lòt lyen.');}finally{setBusy(false);}}
return <><Header/><main className="container page"><section className="card form-card"><h1>Nouvo modpas</h1><form onSubmit={submit}><div className="field"><label htmlFor="password">Nouvo modpas</label><input id="password" type="password" minLength={10} required value={password} onChange={e=>setPassword(e.target.value)}/></div><button className="button" disabled={busy}>{busy?'Ap sove…':'Chanje modpas'}</button></form>{message&&<div className="notice notice-info">{message}</div>}<Link href="/connexion">Ale nan koneksyon</Link></section></main></>}
