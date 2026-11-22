'use client';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

async function post(url: string, body: unknown) {
  const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  if (!r.ok) alert(((await r.json().catch(() => ({}))) as { error?: string }).error ?? 'Yon erè fèt.');
}

export function RoleSelect({ id, role }: { id: string; role: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <select defaultValue={role} disabled={busy} aria-label="Wòl" onChange={async (e) => { setBusy(true); await post('/api/admin/roles', { user_id: id, role: e.target.value }); setBusy(false); router.refresh(); }}>
      <option value="kliyan">Kliyan</option><option value="kanesa">Kanèsa</option><option value="admin">Admin</option>
    </select>
  );
}

export function KanesaSelect({ planId, current, options }: { planId: string; current: string | null; options: { id: string; name: string }[] }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <select defaultValue={current ?? ''} disabled={busy} aria-label="Kanèsa" onChange={async (e) => { setBusy(true); await post('/api/admin/kanesa', { plan_id: planId, kanesa_id: e.target.value || null }); setBusy(false); router.refresh(); }}>
      <option value="">Pa gen Kanèsa</option>{options.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
    </select>
  );
}
