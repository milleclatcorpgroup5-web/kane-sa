'use client';

import { useState, type FormEvent } from 'react';

type Controls = { deposits_enabled: boolean; withdrawal_requests_enabled: boolean; public_notice: string | null };
export function AdminSystemControls({ initial }: { initial: Controls }) {
  const [deposits, setDeposits] = useState(initial.deposits_enabled);
  const [withdrawals, setWithdrawals] = useState(initial.withdrawal_requests_enabled);
  const [notice, setNotice] = useState(initial.public_notice || '');
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('');
    try {
      const response = await fetch('/api/admin/system-controls', { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ deposits_enabled: deposits, withdrawal_requests_enabled: withdrawals, public_notice: notice.trim() || null }) });
      const data = await response.json(); if (!response.ok) throw new Error(data.error || 'Pa t kapab sove kontwòl yo.'); setMessage('Kontwòl operasyon yo sove.');
    } catch (error) { setMessage(error instanceof Error ? error.message : 'Erè.'); }
    finally { setBusy(false); }
  }
  return <form onSubmit={submit}>
    <label className="checkline"><input type="checkbox" checked={deposits} onChange={(e) => setDeposits(e.target.checked)} /> Aksepte nouvo demann depo</label>
    <label className="checkline"><input type="checkbox" checked={withdrawals} onChange={(e) => setWithdrawals(e.target.checked)} /> Aksepte nouvo demann retrè</label>
    <div className="field"><label htmlFor="system-notice">Mesaj estati pou kliyan (opsyonèl)</label><textarea id="system-notice" maxLength={320} value={notice} onChange={(e) => setNotice(e.target.value)} placeholder="Egzanp: Gen yon antretyen pwograme..." /></div>
    <p className="small muted">Lè ou sispann yon fonksyon, backend ak bazdone bloke nouvo demann yo. Sa pa anile ni pa peye demann ki deja egziste yo.</p>
    <button className="button" disabled={busy}>{busy ? 'Ap sove…' : 'Sove kontwòl global'}</button>{message && <p className="small muted" role="status">{message}</p>}
  </form>;
}
