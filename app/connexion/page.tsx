'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { Header } from '@/components/header';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const router=useRouter();
  const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [message,setMessage]=useState(''); const [busy,setBusy]=useState(false);
  async function submit(e:FormEvent<HTMLFormElement>) { e.preventDefault();setBusy(true);setMessage('');try{const supabase=createClient();const {error}=await supabase.auth.signInWithPassword({email,password});if(error)throw error;const requestedNext=new URLSearchParams(window.location.search).get('next');const destination=requestedNext?.startsWith('/')&&!requestedNext.startsWith('//')?requestedNext:'/tableau-de-bord';router.replace(destination);router.refresh();}catch(error){setMessage(error instanceof Error?error.message:'Koneksyon an echwe.');}finally{setBusy(false);} }
  return <><Header/><main className="container page"><section className="card form-card"><h1>Byenveni ankò</h1><p className="muted">Konekte pou antre nan espas ekonomi pèsonèl ou.</p><form onSubmit={submit}><div className="field"><label htmlFor="email">Imel</label><input id="email" type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)}/></div><div className="field"><label htmlFor="password">Modpas</label><input id="password" type="password" autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)}/></div><button className="button" disabled={busy}>{busy?'Ap konekte…':'Konekte'}</button></form>{message&&<div className="notice notice-danger">{message}</div>}<div className="auth-links"><Link href="/mot-de-passe-oublie">Ou bliye modpas ou?</Link><Link href="/inscription">Kreye kont</Link></div></section></main></>;
}
