'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const tabs = [
  { href: '/tableau-de-bord', label: 'Akèy', icon: '🏠' },
  { href: '/kontwol', label: 'Kontwòl', icon: '📊' },
  { href: '/depots/nouveau', label: 'Depo', icon: '➕' },
  { href: '/retraits/nouveau', label: 'Retrè', icon: '💸' },
  { href: '/historique', label: 'Istorik', icon: '🧾' },
];

export function BottomNav() {
  const path = usePathname();
  return (
    <nav className="bottom-nav" aria-label="Navigasyon mobil">
      {tabs.map((t) => (
        <Link key={t.href} href={t.href} aria-current={path === t.href ? 'page' : undefined}><span aria-hidden>{t.icon}</span>{t.label}</Link>
      ))}
    </nav>
  );
}
