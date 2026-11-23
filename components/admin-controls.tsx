'use client';

import { useState } from 'react';

async function post(url: string, body: Record<string, string> = {}) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || 'Aksyon an echwe.');
}

export function AdminDepositControls({ id }: { id: string }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  async function run(action: 'confirm' | 'reject') {
    let value = '';
    if (action === 'confirm') {
      const entered = window.prompt('Antre referans tranzaksyon ou verifye sou sous ofisyèl la:');
      if (entered === null) return;
      value = entered.trim();
      if (!value) {
        setMessage('Referans verifikasyon an obligatwa.');
        return;
      }
      if (!window.confirm('Èske ou verifye tranzaksyon an sou sous ofisyèl la?')) return;
    } else {
      value = window.prompt('Rezon refi a (opsyonèl):')?.trim() ?? '';
    }

    setBusy(true);
    setMessage('');
    try {
      await post(
        `/api/admin/depots/${id}/${action === 'confirm' ? 'confirmer' : 'refize'}`,
        action === 'confirm' ? { reference: value } : { note: value },
      );
      window.location.reload();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Erè pandan aksyon an.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="actions">
      <button className="button green" disabled={busy} onClick={() => run('confirm')}>Konfime depo</button>
      <button className="button secondary" disabled={busy} onClick={() => run('reject')}>Refize</button>
      {message && <span className="small" role="alert">{message}</span>}
    </div>
  );
}

export function AdminWithdrawalControls({ id, status }: { id: string; status: string }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  async function review(decision: 'approved' | 'rejected') {
    const note = window.prompt('Nòt administratè (opsyonèl):')?.trim() ?? '';
    setBusy(true);
    setMessage('');
    try {
      await post(`/api/admin/retraits/${id}/examiner`, { decision, note });
      window.location.reload();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Erè pandan revizyon an.');
    } finally {
      setBusy(false);
    }
  }

  async function markPaid() {
    const entered = window.prompt('Antre referans peman an (obligatwa):');
    if (entered === null) return;
    const reference = entered.trim();
    if (!reference) {
      setMessage('Referans peman an obligatwa.');
      return;
    }
    setBusy(true);
    setMessage('');
    try {
      await post(`/api/admin/retraits/${id}/payer`, { reference });
      window.location.reload();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Erè pandan anrejistreman peman an.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="actions">
      {status === 'pending' && <>
        <button className="button green" disabled={busy} onClick={() => review('approved')}>Apwouve</button>
        <button className="button secondary" disabled={busy} onClick={() => review('rejected')}>Refize</button>
      </>}
      {status === 'approved' && <button className="button green" disabled={busy} onClick={markPaid}>Make kòm peye</button>}
      {message && <span className="small" role="alert">{message}</span>}
    </div>
  );
}
