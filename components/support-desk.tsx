'use client';

import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

export type SupportMessage = { id: string; sender_id: string; body: string; created_at: string };
export type SupportTicket = {
  id: string; subject: string; category: string; status: string; priority: string;
  created_at: string; updated_at: string; last_message_at: string; messages: SupportMessage[];
};

const statusNames: Record<string, string> = {
  open: 'Louvri', in_progress: 'An tretman', waiting_customer: 'Ap tann kliyan', resolved: 'Rezoud', closed: 'Fèmen',
};
const categoryNames: Record<string, string> = {
  account: 'Kont', deposit: 'Depo', withdrawal: 'Retrè', savings_plan: 'Plan ekonomi', security: 'Sekirite', other: 'Lòt',
};

export function SupportDesk({ tickets, userId }: { tickets: SupportTicket[]; userId: string }) {
  const router = useRouter();
  const [subject, setSubject] = useState('');
  const [category, setCategory] = useState('other');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');

  async function openTicket(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setNotice('');
    try {
      const response = await fetch('/api/support/tickets', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ subject, category, message }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Nou pa t kapab louvri dosye a.');
      setSubject(''); setMessage(''); setNotice('Dosye sipò a kreye. Ekip la ap kapab reponn nan menm fil la.'); router.refresh();
    } catch (error) { setNotice(error instanceof Error ? error.message : 'Erè.'); }
    finally { setBusy(false); }
  }

  async function reply(event: FormEvent<HTMLFormElement>, ticketId: string) {
    event.preventDefault(); const form = event.currentTarget; const value = new FormData(form).get('message');
    if (typeof value !== 'string' || !value.trim()) return;
    setBusy(true); setNotice('');
    try {
      const response = await fetch(`/api/support/tickets/${ticketId}/messages`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message: value }) });
      const data = await response.json(); if (!response.ok) throw new Error(data.error || 'Pa t kapab voye mesaj la.');
      form.reset(); router.refresh();
    } catch (error) { setNotice(error instanceof Error ? error.message : 'Erè.'); }
    finally { setBusy(false); }
  }

  return <div className="support-layout">
    <section className="card">
      <h2>Louvri yon dosye sipò</h2>
      <p className="muted small">Pa voye PIN, modpas, kòd OTP oswa nimewo dokiman konplè nan mesaj sipò.</p>
      <form onSubmit={openTicket}>
        <div className="field"><label htmlFor="support-subject">Sijè</label><input id="support-subject" minLength={4} maxLength={120} required value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Egzanp: Mwen gen yon kesyon sou depo mwen" /></div>
        <div className="field"><label htmlFor="support-category">Kategori</label><select id="support-category" value={category} onChange={(e) => setCategory(e.target.value)}><option value="account">Kont</option><option value="deposit">Depo</option><option value="withdrawal">Retrè</option><option value="savings_plan">Plan ekonomi</option><option value="security">Sekirite</option><option value="other">Lòt</option></select></div>
        <div className="field"><label htmlFor="support-message">Mesaj</label><textarea id="support-message" minLength={1} maxLength={4000} required value={message} onChange={(e) => setMessage(e.target.value)} placeholder="Eksplike pwoblèm nan san mete enfòmasyon sekrè." /></div>
        <button className="button" disabled={busy}>{busy ? 'Ap voye…' : 'Kreye dosye sipò'}</button>
      </form>
      {notice && <p className="small muted" role="status">{notice}</p>}
    </section>
    <section>
      <div className="section-title" style={{ marginTop: 0 }}><h2>Dosye mwen yo</h2><span className="pill">{tickets.length} dosye</span></div>
      {!tickets.length ? <div className="empty">Ou poko gen dosye sipò.</div> : tickets.map((ticket) => <article className="card support-ticket" key={ticket.id}>
        <div className="support-ticket-head"><div><span className="eyebrow">{categoryNames[ticket.category] || ticket.category}</span><h3>{ticket.subject}</h3><span className="pill">{statusNames[ticket.status] || ticket.status}</span></div><span className="small muted">{new Date(ticket.created_at).toLocaleDateString('fr-HT')}</span></div>
        <div className="support-messages">{ticket.messages.map((item) => <div className={`support-message ${item.sender_id === userId ? 'mine' : ''}`} key={item.id}><p>{item.body}</p><span>{item.sender_id === userId ? 'Ou' : 'Ekip KANÈ SA'} · {new Date(item.created_at).toLocaleString('fr-HT')}</span></div>)}</div>
        {!['resolved', 'closed'].includes(ticket.status) && <form className="support-reply" onSubmit={(e) => reply(e, ticket.id)}><textarea name="message" required maxLength={4000} placeholder="Ekri yon repons…" aria-label="Repons ou"/><button className="button secondary" disabled={busy}>Voye</button></form>}
      </article>)}
    </section>
  </div>;
}

export type AdminSupportTicket = SupportTicket & { user_id: string; user_name: string; user_phone: string | null };
export function AdminSupportManager({ tickets }: { tickets: AdminSupportTicket[] }) {
  const router = useRouter(); const [busy, setBusy] = useState(false); const [notice, setNotice] = useState('');
  async function save(event: FormEvent<HTMLFormElement>, ticketId: string) {
    event.preventDefault(); const form = event.currentTarget; const formData = new FormData(form);
    const status = String(formData.get('status') || 'in_progress'); const reply = String(formData.get('reply') || '').trim();
    setBusy(true); setNotice('');
    try {
      const response = await fetch(`/api/admin/support/tickets/${ticketId}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status, reply: reply || null }) });
      const data = await response.json(); if (!response.ok) throw new Error(data.error || 'Pa t kapab mete ajou dosye a.');
      form.reset(); router.refresh(); setNotice('Dosye sipò a mete ajou.');
    } catch (error) { setNotice(error instanceof Error ? error.message : 'Erè.'); }
    finally { setBusy(false); }
  }
  return <div>
    {notice && <p role="status" className="notice notice-info">{notice}</p>}
    {!tickets.length ? <div className="empty">Pa gen dosye sipò.</div> : tickets.map((ticket) => <article className="card support-ticket" key={ticket.id}>
      <div className="support-ticket-head"><div><span className="eyebrow">{categoryNames[ticket.category] || ticket.category} · {ticket.id.slice(0, 8)}</span><h2>{ticket.subject}</h2><p className="small muted">{ticket.user_name} · {ticket.user_phone || 'Pa gen telefòn'}</p></div><span className="pill">{statusNames[ticket.status] || ticket.status}</span></div>
      <div className="support-messages">{ticket.messages.map((item) => <div className="support-message" key={item.id}><p>{item.body}</p><span>{item.sender_id === ticket.user_id ? 'Kliyan' : 'Ekip KANÈ SA'} · {new Date(item.created_at).toLocaleString('fr-HT')}</span></div>)}</div>
      <form className="admin-support-form" onSubmit={(e) => save(e, ticket.id)}><div className="field"><label>Nouvo estati</label><select name="status" defaultValue={ticket.status}><option value="open">Louvri</option><option value="in_progress">An tretman</option><option value="waiting_customer">Ap tann kliyan</option><option value="resolved">Rezoud</option><option value="closed">Fèmen</option></select></div><div className="field"><label>Repons pou kliyan (opsyonèl)</label><textarea name="reply" maxLength={4000} placeholder="Reponn kliyan an..."/></div><button className="button" disabled={busy}>Sove dosye a</button></form>
    </article>)}
  </div>;
}
