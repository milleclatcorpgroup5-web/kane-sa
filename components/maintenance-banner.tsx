'use client';

import { useEffect, useState } from 'react';

type Status = { maintenance_mode?: boolean; public_notice?: string | null };

export function MaintenanceBanner() {
  const [status, setStatus] = useState<Status | null>(null);
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const response = await fetch('/api/system/status', { cache: 'no-store' });
        if (!response.ok) return;
        const body = await response.json() as { status?: Status };
        if (active) setStatus(body.status ?? null);
      } catch {
        // A temporary status API issue should not hide the rest of the app.
      }
    };
    void load();
    const timer = window.setInterval(load, 60_000);
    return () => { active = false; window.clearInterval(timer); };
  }, []);

  if (!status?.maintenance_mode && !status?.public_notice) return null;
  return <div className={`global-status-banner ${status.maintenance_mode ? 'maintenance' : ''}`} role="status">
    <strong>{status.maintenance_mode ? 'Mòd antretyen aktif' : 'Enfòmasyon KANÈ SA'}</strong>
    <span>{status.public_notice || (status.maintenance_mode ? 'Aksyon ki modifye done yo tanporèman bloke. Ou kapab konsilte enfòmasyon ou yo epi dekonekte.' : '')}</span>
  </div>;
}
