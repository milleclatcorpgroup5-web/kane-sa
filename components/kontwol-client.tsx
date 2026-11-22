'use client';
import { useRouter } from 'next/navigation';
import { useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { EXPENSE_CATEGORIES } from '@/lib/finance';

export function TxForm() {
  const router = useRouter();
  const key = useRef(crypto.randomUUID());
  const [kind, setKind] = useState<'out' | 'in'>('out');
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (busy) return;
    const form = e.currentTarget;
    const f = new FormData(form);
    setBusy(true);
    const res = await fetch('/api/transactions', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'idempotency-key': key.current },
      body: JSON.stringify({ kind, category: kind === 'in' ? 'revni' : f.get('category'), amount: f.get('amount'), note: f.get('note') || undefined }),
    });
    const data = await res.json().catch(() => ({}));
    setBusy(false);
    if (res.ok) { key.current = crypto.randomUUID(); form.reset(); setMsg('Anrejistre ✔'); router.refresh(); }
    else setMsg(data.error ?? 'Yon erè fèt.');
  }
  return (
    <form onSubmit={submit}>
      <div className="seg" role="group" aria-label="Kalite">
        <button type="button" className={kind === 'out' ? 'on' : ''} onClick={() => setKind('out')}>Depans</button>
        <button type="button" className={kind === 'in' ? 'on' : ''} onClick={() => setKind('in')}>Revni</button>
      </div>
      {kind === 'out' && <div className="field"><label htmlFor="category">Kategori</label><select id="category" name="category">{Object.entries(EXPENSE_CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></div>}
      <div className="field"><label htmlFor="amount">Montan (HTG)</label><input id="amount" name="amount" type="number" inputMode="decimal" min="1" step="any" required /></div>
      <div className="field"><label htmlFor="note">Nòt (opsyonèl)</label><input id="note" name="note" maxLength={80} /></div>
      <button className="button" disabled={busy}>{busy ? 'Ap anrejistre…' : 'Anrejistre'}</button>
      <span className="small muted" role="status" style={{ marginLeft: 12 }}>{msg}</span>
    </form>
  );
}

export function BudgetInput({ category, limit }: { category: string; limit: number }) {
  const router = useRouter();
  async function save(value: string) {
    const n = Number(value);
    if (!n || n === limit) return;
    await fetch('/api/budgets', { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ category, monthly_limit: n }) });
    router.refresh();
  }
  return <input className="budget-input" type="number" min="1" defaultValue={limit || ''} placeholder="Limit" aria-label={`Limit ${category}`} onBlur={(e) => save(e.target.value)} />;
}

export function DeleteTx({ id }: { id: string }) {
  const router = useRouter();
  return <button className="link-button" aria-label="Efase tranzaksyon" onClick={async () => { await fetch(`/api/transactions?id=${id}`, { method: 'DELETE' }); router.refresh(); }}>✕</button>;
}
