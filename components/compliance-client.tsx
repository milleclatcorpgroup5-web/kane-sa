'use client';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import type { FormEvent } from 'react';

export function ActionButton({ body, label, secondary }: { body: Record<string, unknown>; label: string; secondary?: boolean }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return <button className={`button${secondary ? ' secondary' : ''}`} disabled={busy} onClick={async () => {
    setBusy(true);
    const r = await fetch('/api/admin/conformite', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
    if (!r.ok) alert(((await r.json().catch(() => ({}))) as { error?: string }).error ?? 'Yon erè fèt.');
    setBusy(false); router.refresh();
  }}>{label}</button>;
}

export function KycForm() {
  const router = useRouter();
  const [msg, setMsg] = useState('');
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = Object.fromEntries(new FormData(e.currentTarget));
    const r = await fetch('/api/kyc', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(f) });
    const d = (await r.json().catch(() => ({}))) as { error?: string };
    if (r.ok) router.refresh(); else setMsg(d.error ?? 'Yon erè fèt.');
  }
  return (
    <form onSubmit={submit}>
      <div className="field"><label htmlFor="legal_name">Non konplè jan l ekri sou dokiman an</label><input id="legal_name" name="legal_name" required minLength={3} maxLength={120} /></div>
      <div className="field"><label htmlFor="date_of_birth">Dat nesans</label><input id="date_of_birth" name="date_of_birth" type="date" required /></div>
      <div className="field"><label htmlFor="address">Adrès</label><input id="address" name="address" required minLength={5} maxLength={240} /></div>
      <div className="field"><label htmlFor="document_type">Kalite dokiman</label><select id="document_type" name="document_type"><option value="cin">CIN</option><option value="passport">Paspò</option><option value="nif">NIF</option><option value="permis">Pèmi kondwi</option></select></div>
      <div className="field"><label htmlFor="document_last4">4 dènye karaktè nimewo dokiman an</label><input id="document_last4" name="document_last4" required pattern="[A-Za-z0-9]{4}" maxLength={4} /><small>Nou pa kenbe nimewo konplè a ni foto dokiman an nan vèsyon sa a.</small></div>
      <button className="button">Voye pou verifikasyon</button> <span className="small muted" role="status">{msg}</span>
    </form>
  );
}
