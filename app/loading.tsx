export default function Loading() {
  return (
    <main className="container page" aria-busy="true" aria-label="Ap chaje">
      <div className="skeleton" style={{ height: 38, width: '55%', marginBottom: 18 }} />
      <div className="grid">{[0, 1, 2, 3].map((i) => <div key={i} className="skeleton" style={{ height: 120 }} />)}</div>
    </main>
  );
}
