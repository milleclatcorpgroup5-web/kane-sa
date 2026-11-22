'use client';
import { useEffect, useState } from 'react';

export function Splash() {
  const [show, setShow] = useState(false);
  useEffect(() => {
    try {
      if (sessionStorage.getItem('kane-splash')) return;
      sessionStorage.setItem('kane-splash', '1');
    } catch { /* sessionStorage ka endisponib */ }
    setShow(true);
    const t = setTimeout(() => setShow(false), 1900);
    return () => clearTimeout(t);
  }, []);
  if (!show) return null;
  return (
    <div className="splash" aria-hidden>
      <span className="brand-mark">K</span>
      <h1>KANÈ SA</h1>
      <p style={{ margin: 0, opacity: .9 }}>Ekonomi ou, anba kontwòl ou.</p>
      <div className="chips"><span>Depo verifye</span><span>Jounal audit</span><span>Done sekirize</span></div>
    </div>
  );
}
