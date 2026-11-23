'use client';

import Link from 'next/link';
import { BottomNav } from './bottom-nav';
import { MaintenanceBanner } from './maintenance-banner';

export function Header({ signedIn = false }: { signedIn?: boolean }) {
  return (
    <>
      <header className="topbar">
        <div className="container topbar-inner">
          <Link href={signedIn ? '/tableau-de-bord' : '/'} className="brand" aria-label="KANÈ SA — Akèy">
            <span className="brand-mark">K</span>
            <span className="brand-copy"><strong>KANÈ SA</strong><small>Ekonomi pèsonèl ou</small></span>
          </Link>

          <nav className="nav-links" aria-label="Navigasyon prensipal">
            {signedIn ? (
              <>
                <Link className="nav-main-link" href="/tableau-de-bord">Akèy</Link>
                <details className="nav-menu">
                  <summary>Ekonomi <span aria-hidden="true">⌄</span></summary>
                  <div className="nav-menu-panel">
                    <Link href="/plans/nouveau"><span>🎯</span><span><strong>Plan ekonomi</strong><small>Kreye oswa òganize objektif ou</small></span></Link>
                    <Link href="/depots/nouveau"><span>➕</span><span><strong>Fè yon depo</strong><small>Soumèt yon demann depo</small></span></Link>
                    <Link href="/retraits/nouveau"><span>↗</span><span><strong>Retrè</strong><small>Konsilte frè anvan konfimasyon</small></span></Link>
                  </div>
                </details>
                <details className="nav-menu">
                  <summary>Aktivite <span aria-hidden="true">⌄</span></summary>
                  <div className="nav-menu-panel">
                    <Link href="/historique"><span>🧾</span><span><strong>Istorik</strong><small>Depo, retrè ak resi</small></span></Link>
                    <Link href="/notifikasyon"><span>🔔</span><span><strong>Notifikasyon</strong><small>Mesaj sou kont ou</small></span></Link>
                    <Link href="/kontwol"><span>📊</span><span><strong>Kontwòl finansye</strong><small>Bidjè ak analiz depans</small></span></Link>
                  </div>
                </details>
                <details className="nav-menu">
                  <summary>Èd ak sèvis <span aria-hidden="true">⌄</span></summary>
                  <div className="nav-menu-panel nav-menu-panel-right">
                    <Link href="/kyc"><span>🪪</span><span><strong>Verifikasyon idantite</strong><small>Enfòmasyon KYC</small></span></Link>
                    <Link href="/konsèy-finansye"><span>💡</span><span><strong>Konsèy finansye</strong><small>Planifye ekonomi ou</small></span></Link>
                    <Link href="/sipo"><span>💬</span><span><strong>Sant sipò</strong><small>Jwenn asistans</small></span></Link>
                  </div>
                </details>
                <form action="/api/auth/logout" method="post" className="nav-logout">
                  <button className="link-button" type="submit">Dekonekte</button>
                </form>
              </>
            ) : (
              <>
                <Link href="/conditions">Kondisyon</Link>
                <Link href="/confidentialite">Vi prive</Link>
                <Link href="/connexion">Konekte</Link>
                <Link className="nav-cta" href="/inscription">Kreye kont</Link>
              </>
            )}
          </nav>
        </div>
      </header>
      {signedIn && <MaintenanceBanner />}
      {signedIn && <BottomNav />}
    </>
  );
}
