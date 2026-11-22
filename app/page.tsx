import Link from 'next/link';
import { Header } from '@/components/header';
import { SavingsSimulator } from '@/components/savings-simulator';

export const metadata = { title: 'Ekonomi pèsonèl ou, anba kontwòl ou', robots: { index: true, follow: true } };

export default function Home() {
  return <>
    <Header />
    <main className="container page">
      <section className="hero">
        <div className="eyebrow">Ekonomi pèsonèl · Klète · Kontwòl</div>
        <h1>Ti pa pa ti pa, bati ekonomi ou.</h1>
        <p>KANÈ SA ede w òganize ekonomi pèsonèl ou nan yon espas dijital. Kreye plan ak objektif oswa ekonomize san objektif, suiv depo ou yo epi konsilte tout aktivite kont ou.</p>
        <div className="actions"><Link className="button" href="/inscription">Kreye kont mwen</Link><Link className="button secondary" href="/connexion">Mwen deja gen kont</Link></div>
      </section>
      <SavingsSimulator />
      <div className="section-title"><h2>Sa ou kapab fè</h2><span className="muted small">Kont pèsonèl, pa ekonomi kolektif</span></div>
      <section className="grid">
        <article className="card"><h3>🎯 Ekonomi ak objektif</h3><p className="muted">Chwazi yon montan ou ta renmen rive jwenn, tankou 20 000 HTG, epi suiv pwogrè ou.</p></article>
        <article className="card"><h3>🌱 Ekonomi fleksib</h3><p className="muted">Mete lajan lè ou kapab, san obligasyon pou respekte yon kalandriye kontribisyon fiks.</p></article>
        <article className="card"><h3>🧾 Istorik ak resi</h3><p className="muted">Wè demann depo, depo ki konfime, demann retrè ak sitiyasyon yo.</p></article>
        <article className="card"><h3>🔐 Sekirite ak verifikasyon</h3><p className="muted">Yon depo pa antre nan balans lan toutotan li pa verifye epi konfime nan sistèm nan.</p></article>
      </section>
      <section className="notice notice-warning" style={{marginTop:24}}><strong>Enpòtan:</strong> KANÈ SA se yon baz aplikasyon pou devlopman ak tès. Li poko konekte ak API MonCash/NatCash, li poko otorize pou kenbe oswa jere lajan reyèl, epi li pa dwe lanse kòm sèvis finansye anvan verifikasyon legal, regilasyon, sekirite ak peman.</section>
    </main>
    <footer className="footer container">© {new Date().getFullYear()} KANÈ SA · <Link href="/conditions">Kondisyon itilizasyon</Link> · <Link href="/confidentialite">Vi prive</Link></footer>
  </>;
}
