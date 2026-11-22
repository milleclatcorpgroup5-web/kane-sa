'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import Link from 'next/link';

type NotificationItem = { id: string; kind: string; title: string; body: string; href: string; created_at: string; read_at: string | null };

export function NotificationList({ items }: { items: NotificationItem[] }) {
  const router = useRouter(); const [busy, setBusy] = useState<string | null>(null); const [error, setError] = useState('');
  async function markRead(id: string) {
    setBusy(id); setError('');
    try {
      const response = await fetch('/api/notifications', { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id }) });
      const data = await response.json(); if (!response.ok) throw new Error(data.error || 'Pa kapab mete kòm li.'); router.refresh();
    } catch (err) { setError(err instanceof Error ? err.message : 'Erè.'); }
    finally { setBusy(null); }
  }
  if (!items.length) return <div className="empty">Ou poko gen notifikasyon.</div>;
  return <div className="notification-list">{error && <p className="notice notice-warning">{error}</p>}{items.map((item) => <article className={`card notification-item ${item.read_at ? '' : 'unread'}`} key={item.id}>
    <div><div className="notification-heading"><strong>{item.title}</strong>{!item.read_at && <span className="pill">Nouvo</span>}</div><p>{item.body}</p><span className="small muted">{new Date(item.created_at).toLocaleString('fr-HT')}</span></div>
    <div className="actions"><Link className="button secondary" href={item.href}>Louvri</Link>{!item.read_at && <button className="button" disabled={busy === item.id} onClick={() => markRead(item.id)}>{busy === item.id ? 'Ap sove…' : 'Make kòm li'}</button>}</div>
  </article>)}</div>;
}
