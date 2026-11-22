'use client';
export default function ErrorPage({ reset }: { error: Error; reset: () => void }) {
  return (
    <main className="container page"><div className="card form-card"><h2>Yon bagay pa mache</h2><p className="muted">Lajan ou an sekirite. Eseye ankò, epi si pwoblèm nan rete, kontakte sipò a.</p><button className="button" onClick={reset}>Eseye ankò</button></div></main>
  );
}
