'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const tabs = [
  { href: '/tableau-de-bord', label: 'Akèy', icon: '⌂' },
  { href: '/plans/nouveau', label: 'Plan', icon: '◎' },
  { href: '/depots/nouveau', label: 'Depo', icon: '+' },
  { href: '/retraits/nouveau', label: 'Retrè', icon: '↗' },
  { href: '/historique', label: 'Istorik', icon: '▤' },
];

export function BottomNav() {
  const path = usePathname();
  return (
    <nav className="bottom-nav" aria-label="Navigasyon prensipal mobil">
      {tabs.map((tab) => {
        const active = path === tab.href || (tab.href !== '/tableau-de-bord' && path.startsWith(tab.href));
        return (
          <Link key={tab.href} href={tab.href} aria-current={active ? 'page' : undefined}>
            <span aria-hidden="true">{tab.icon}</span>
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
