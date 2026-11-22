'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Header } from '@/components/header';
import { createClient } from '@/lib/supabase/client';

export default function ForgotPasswordPage(){const [email,setEmail]=useState('');const [message,setMessage]=useState('');const [busy,setBusy]=useState(false);
async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage('');try{const supabase=createClient();const {error}=await supabase.auth.resetPasswordForEmail(email,{redirectTo:`${window.location.origin}/nouvo-modpas`});if(error)throw error;setMessage('Si adrès la asosye ak yon kont, yon imel pou reset ap voye. Tcheke bwat resepsyon ak spam ou.');}catch(err){setMessage(err instanceof Error?err.message:'Nou pa rive voye imel la.');}finally{setBusy(false);}}
return <><Header/><main className="container page"><section className="card form-card"><h1>Reyinisyalize modpas</h1><p className="muted">Antre imel kont ou. N ap voye yon lyen pou kreye yon nouvo modpas.</p><form onSubmit={submit}><div className="field"><label htmlFor="email">Adrès imel</label><input id="email" type="email" required value={email} onChange={e=>setEmail(e.target.value)}/></div><button className="button" disabled={busy}>{busy?'Ap voye…':'Voye lyen an'}</button></form>{message&&<div className="notice notice-info">{message}</div>}<p className="small"><Link href="/connexion">Retounen konekte</Link></p></section></main></>}
