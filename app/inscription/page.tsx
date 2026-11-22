'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Header } from '@/components/header';
import { createClient } from '@/lib/supabase/client';

export default function SignupPage() {
  const [fullName,setFullName]=useState(''); const [phone,setPhone]=useState(''); const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [message,setMessage]=useState(''); const [busy,setBusy]=useState(false);
  async function submit(e:FormEvent<HTMLFormElement>) {
    e.preventDefault(); setBusy(true); setMessage('');
    try {
      const supabase=createClient();
      const {error}=await supabase.auth.signUp({email,password,options:{data:{full_name:fullName.trim(),phone:phone.trim()},emailRedirectTo:`${window.location.origin}/auth/confirm`}});
      if(error) throw error;
      setMessage('Kont la kreye. Tcheke imel ou pou verifye adrès la, si verifikasyon imel aktive nan Supabase. Pwofil la kreye otomatikman pa baz done a.');
    } catch(error) { setMessage(error instanceof Error?error.message:'Nou pa rive kreye kont lan.'); }
    finally { setBusy(false); }
  }
  return <><Header/><main className="container page"><section className="card form-card"><h1>Kreye kont KANÈ SA</h1><p className="muted">Enfòmasyon sa yo ap sèvi pou idantifye kont pèsonèl ou.</p><form onSubmit={submit}>
    <div className="field"><label htmlFor="name">Non konplè</label><input id="name" autoComplete="name" required minLength={2} maxLength={120} value={fullName} onChange={e=>setFullName(e.target.value)}/></div>
    <div className="field"><label htmlFor="phone">Nimewo telefòn</label><input id="phone" autoComplete="tel" type="tel" required maxLength={30} placeholder="+509..." value={phone} onChange={e=>setPhone(e.target.value)}/></div>
    <div className="field"><label htmlFor="email">Adrès imel</label><input id="email" autoComplete="email" type="email" required value={email} onChange={e=>setEmail(e.target.value)}/></div>
    <div className="field"><label htmlFor="password">Modpas</label><input id="password" autoComplete="new-password" type="password" minLength={10} required value={password} onChange={e=>setPassword(e.target.value)}/><small>Omwen 10 karaktè. Pa pataje modpas ou ak pèsonn.</small></div>
    <button className="button" disabled={busy}>{busy?'Ap kreye kont…':'Kreye kont mwen'}</button>
  </form>{message&&<div className="notice notice-info">{message}</div>}<div className="auth-links"><span>Ou deja gen kont?</span><Link href="/connexion">Konekte</Link></div></section></main></>;
}
