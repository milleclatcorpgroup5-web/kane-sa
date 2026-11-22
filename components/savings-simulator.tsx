'use client';
import Link from 'next/link';
import { useState } from 'react';
import { money } from '@/lib/format';

export function SavingsSimulator() {
  const [goal, setGoal] = useState(30000);
  const [monthly, setMonthly] = useState(2500);
  const months = Math.ceil(goal / monthly);
  const when = new Date();
  when.setMonth(when.getMonth() + months);
  return (
    <section className="card" style={{ marginBottom: 24 }}>
      <h2>Konbyen tan pou m rive?</h2>
      <div className="field"><label htmlFor="sim-goal">Objektif mwen: {money(goal)}</label><input id="sim-goal" type="range" min={5000} max={200000} step={1000} value={goal} onChange={(e) => setGoal(+e.target.value)} /></div>
      <div className="field"><label htmlFor="sim-m">Mwen ka mete chak mwa: {money(monthly)}</label><input id="sim-m" type="range" min={500} max={20000} step={500} value={monthly} onChange={(e) => setMonthly(+e.target.value)} /></div>
      <div className="progress"><span style={{ width: `${Math.min(100, (12 / months) * 100)}%` }} /></div>
      <p>Ou ap rive nan <b>{months} mwa</b>, anviwon {when.toLocaleDateString('fr-HT', { month: 'long', year: 'numeric' })}.</p>
      <Link className="button" href="/inscription">Kòmanse kounye a</Link>
    </section>
  );
}
