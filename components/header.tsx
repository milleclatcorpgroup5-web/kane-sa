'use client';

import Link from 'next/link';
import { BottomNav } from './bottom-nav';
import { MaintenanceBanner } from './maintenance-banner';

export function Header({ signedIn = false }: { signedIn?: boolean }) {
  return (
    <>
    <header className="topbar">
      <div className="container topbar-inner">
        <Link href="/" className="brand"><span className="brand-mark">K</span><span>KANÈ SA</span></Link>
        <nav className="nav-links" aria-label="Navigasyon prensipal">
          {signedIn ? <>
            <Link href="/tableau-de-bord">Tablo bò</Link>
            <Link href="/kontwol">Kontwòl</Link>
            <Link href="/kyc">KYC</Link>
            <Link href="/plans/nouveau">Nouvo plan</Link>
            <Link href="/depots/nouveau">Depo</Link>
            <Link href="/retraits/nouveau">Retrè</Link>
            <Link href="/historique">Istorik</Link>
            <Link href="/notifikasyon">Notifikasyon</Link>
            <Link href="/konsèy-finansye">Konsèy</Link>
            <Link href="/sipo">Sipò</Link>
            <form action="/api/auth/logout" method="post"><button className="link-button" type="submit">Dekonekte</button></form>
          </> : <>
            <Link href="/connexion">Konekte</Link>
            <Link className="nav-cta" href="/inscription">Kreye kont</Link>
          </>}
        </nav>
      </div>
    </header>
    {signedIn && <MaintenanceBanner />}
    {signedIn && <BottomNav />}
    </>
  );
}
