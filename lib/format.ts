export function money(value: number | string | null | undefined): string {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat('fr-HT', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number.isFinite(amount) ? amount : 0) + ' HTG';
}

export function dateTime(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat('fr-HT', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
}

export function statusLabel(status: string): string {
  const labels: Record<string, string> = {
    active: 'Aktif', paused: 'Mete an poz', closed: 'Fèmen', pending: 'An atant',
    confirmed: 'Konfime', rejected: 'Refize', approved: 'Otorize — poko peye', paid: 'Peye',
  };
  return labels[status] ?? status;
}
