'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { Header } from '@/components/header';

type SavingsPlan = {
  id: string;
  title: string;
  available_balance: number;
  balance?: number;
  has_goal: boolean;
  goal_amount: number | null;
};

type WithdrawalQuote = {
  available_balance: number;
  has_goal: boolean;
  goal_amount: number | null;
  goal_reached: boolean;
  balance?: number;
  kind: 'normal' | 'emergency';
  fee_percent: number;
  fee_amount: number;
  gross_amount: number;
  net_amount: number;
  fees_enabled: boolean;
  reason_required: boolean;
  manual_review: boolean;
  manual_review_reason: string | null;
  kyc_required: boolean;
};

const money = (value: number) => new Intl.NumberFormat('fr-HT', {
  minimumFractionDigits: 2, maximumFractionDigits: 2,
}).format(Number(value || 0)) + ' HTG';

export default function NewWithdrawalPage() {
  const [plans, setPlans] = useState<SavingsPlan[]>([]);
  const [planId, setPlanId] = useState('');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [details, setDetails] = useState('');
  const [method, setMethod] = useState('moncash');
  const [quote, setQuote] = useState<WithdrawalQuote | null>(null);
  const [quoteError, setQuoteError] = useState('');
  const [accepted, setAccepted] = useState(false);
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [loadingPlans, setLoadingPlans] = useState(true);
  const [withdrawalsEnabled, setWithdrawalsEnabled] = useState(true);
  const [systemNotice, setSystemNotice] = useState('');
  const idempotencyKey = useRef<string | null>(null);

  useEffect(() => {
    fetch('/api/system/status').then((response) => response.ok ? response.json() : null).then((data) => {
      if (data?.status) { setWithdrawalsEnabled(data.status.withdrawal_requests_enabled); setSystemNotice(data.status.public_notice || ''); }
    }).catch(() => undefined);
  }, []);

  useEffect(() => {
    let active = true;
    async function loadPlans() {
      setLoadingPlans(true);
      try {
        const response = await fetch('/api/plans');
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Nou pa rive chaje plan yo.');
        if (!active) return;
        const list = (data.plans || []) as SavingsPlan[];
        setPlans(list);
        if (list[0]) setPlanId(list[0].id);
      } catch (error) {
        if (active) setQuoteError(error instanceof Error ? error.message : 'Erè pandan chajman plan yo.');
      } finally {
        if (active) setLoadingPlans(false);
      }
    }
    void loadPlans();
    return () => { active = false; };
  }, []);

  useEffect(() => {
    setQuote(null);
    setQuoteError('');
    setAccepted(false);
    idempotencyKey.current = null;
    const numericAmount = Number(amount);
    if (!planId || !amount || !Number.isFinite(numericAmount) || numericAmount <= 0) return;
    const controller = new AbortController();
    const timer = setTimeout(async () => {
      try {
        const response = await fetch('/api/retraits/quote', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ plan_id: planId, gross_amount: numericAmount }),
          signal: controller.signal,
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Nou pa rive kalkile retrè a.');
        setQuote(data.quote as WithdrawalQuote);
      } catch (error) {
        if (!controller.signal.aborted) {
          setQuoteError(error instanceof Error ? error.message : 'Nou pa rive kalkile retrè a.');
        }
      }
    }, 350);
    return () => { clearTimeout(timer); controller.abort(); };
  }, [planId, amount]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!withdrawalsEnabled) { setMessage('Nouvo demann retrè yo sispann tanporèman. Tanpri eseye ankò pita.'); return; }
    if (!quote) { setMessage('Tann kalkil frè a fini anvan ou konfime.'); return; }
    if (quote.reason_required && !reason) { setMessage('Chwazi rezon ijans lan.'); return; }
    if (!accepted) { setMessage('Ou dwe konfime ou wè frè ak montan net la.'); return; }
    setBusy(true);
    setMessage('');
    try {
      idempotencyKey.current ||= crypto.randomUUID();
      const response = await fetch('/api/retraits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          plan_id: planId,
          gross_amount: Number(amount),
          kind: quote.kind,
          reason_category: quote.reason_required ? reason : null,
          reason_text: quote.reason_required ? details : null,
          payment_method: method,
          expected_fee_percent: quote.fee_percent,
          idempotency_key: idempotencyKey.current,
        }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Nou pa rive soumèt demann lan.');
      if (data.status === 'pending') {
        setMessage('Demann lan anrejistre, men sistèm nan mete li an atant pou verifikasyon sekirite. Se sèlman ka ki gen risk ki mande revizyon admin.');
      } else {
        setMessage('Retrè a otorize otomatikman. Sa pa vle di lajan an deja peye: peman an dwe egzekite atravè kanal peman ki otorize a.');
      }
      idempotencyKey.current = null;
      setAmount('');
      setReason('');
      setDetails('');
      setAccepted(false);
      setQuote(null);
    } catch (error) {
      // Nou kenbe menm idempotency key la si rezo a echwe, pou retry pa kreye yon dezyèm retrè.
      setMessage(error instanceof Error ? error.message : 'Erè pandan demann retrè a.');
    } finally {
      setBusy(false);
    }
  }

  const selectedPlan = plans.find((plan) => plan.id === planId);

  return <>
    <Header signedIn />
    <main className="container page">
      <section className="card form-card">
        <span className="eyebrow">KANÈ SA · Retrè</span>
        <h1>Retire lajan</h1>
        <p className="muted">Règ retrè a detèmine otomatikman selon plan ekonomi ou. Ou ap wè frè ak kantite nèt la anvan ou konfime.</p>

        {systemNotice && <div className="notice notice-info">{systemNotice}</div>}
        {!withdrawalsEnabled && <div className="notice notice-danger">Nouvo demann retrè yo sispann tanporèman. Demann ki deja egziste yo pa afekte.</div>}
        <div className="notice notice-info">
          <strong>Otorize otomatikman:</strong> retrè nòmal yo pa bezwen apwobasyon admin youn apre lòt. Sistèm nan kenbe sèlman demann ki rive sou kontwòl risk yo pou revizyon.
        </div>
        <div className="notice notice-warning">
          <strong>Enpòtan:</strong> otorizasyon otomatik nan aplikasyon an pa vle di MonCash, NatCash oswa bank deja voye lajan an. Peman ekstèn otomatik ap mande entegrasyon ofisyèl founisè a.
        </div>

        <form onSubmit={submit}>
          <div className="field">
            <label htmlFor="plan">Plan ekonomi</label>
            <select id="plan" required value={planId} onChange={(event) => setPlanId(event.target.value)} disabled={loadingPlans}>
              <option value="">{loadingPlans ? 'Ap chaje plan yo…' : 'Chwazi plan an'}</option>
              {plans.map((plan) => <option key={plan.id} value={plan.id}>
                {plan.title} — disponib: {money(Number(plan.available_balance))}
                {plan.has_goal ? ' · Ak objektif' : ' · San objektif'}
              </option>)}
            </select>
          </div>

          {selectedPlan && <div className="notice notice-info">
            {selectedPlan.has_goal
              ? `Plan sa a gen objektif ${money(Number(selectedPlan.goal_amount || 0))}. Si objektif la poko rive nan montan li, retrè a klase ijans otomatikman.`
              : 'Plan sa a pa gen objektif fikse. Règ frè retrè nòmal la ap aplike.'}
          </div>}

          <div className="field">
            <label htmlFor="amount">Montan brit ou vle retire (HTG)</label>
            <input id="amount" type="number" min="1" max="10000000" step="0.01" required value={amount} onChange={(event) => setAmount(event.target.value)} inputMode="decimal" />
          </div>

          {quote && <section className="card" aria-live="polite">
            <div className="tx-row"><span className="muted">Kategori retrè</span><strong>{quote.kind === 'emergency' ? 'Ijans — objektif poko rive' : 'Nòmal'}</strong></div>
            <div className="tx-row"><span className="muted">Montan brit</span><strong>{money(quote.gross_amount)}</strong></div>
            <div className="tx-row"><span className="muted">Frè ({quote.fee_percent.toFixed(2)}%)</span><strong>{money(quote.fee_amount)}</strong></div>
            <div className="tx-row"><span className="muted">Ou pral resevwa</span><strong>{money(quote.net_amount)}</strong></div>
            {!quote.fees_enabled && <p className="small muted">Frè yo dezaktive kounye a; kalkil la montre 0 HTG. Nenpòt frè dwe pibliye davans.</p>}
            {quote.manual_review && <p className="small">Demann sa a ka mande verifikasyon sekirite anvan otorizasyon.</p>}
            {quote.kyc_required && <p className="small">Verifikasyon idantite obligatwa pou montan sa a. <Link href="/kyc">Fini KYC mwen</Link>.</p>}
          </section>}
          {quoteError && <div className="notice notice-warning">{quoteError}</div>}

          {quote?.reason_required && <>
            <div className="field">
              <label htmlFor="reason">Rezon retrè ijans</label>
              <select id="reason" required value={reason} onChange={(event) => setReason(event.target.value)}>
                <option value="">Chwazi rezon an</option>
                <option value="medical">Ijans medikal</option>
                <option value="death">Lanmò nan fanmi</option>
                <option value="family_emergency">Ijans familyal</option>
                <option value="other">Lòt ijans</option>
              </select>
            </div>
            <div className="field">
              <label htmlFor="details">Eksplikasyon (opsyonèl)</label>
              <textarea id="details" maxLength={500} value={details} onChange={(event) => setDetails(event.target.value)} placeholder="Pa mete enfòmasyon pèsonèl oswa medikal ki pa nesesè." />
            </div>
          </>}

          <div className="field">
            <label htmlFor="method">Metòd ou prefere resevwa lajan an</label>
            <select id="method" value={method} onChange={(event) => setMethod(event.target.value)}>
              <option value="moncash">MonCash</option>
              <option value="natcash">NatCash</option>
              <option value="cash">Lajan kach / ajan</option>
              <option value="bank">Bank</option>
            </select>
          </div>

          <label className="checkline">
            <input type="checkbox" checked={accepted} onChange={(event) => setAccepted(event.target.checked)} />
            Mwen verifye montan brit, frè ak montan nèt mwen pral resevwa.
          </label>
          <button className="button" disabled={busy || !withdrawalsEnabled || !quote || !accepted || quote.kyc_required || (quote.reason_required && !reason)}>
            {!withdrawalsEnabled ? 'Retrè sispann' : busy ? 'Ap trete…' : 'Konfime retrè a'}
          </button>
        </form>
        {message && <div className="notice notice-info" role="status">{message}</div>}
        <p className="small"><Link href="/tableau-de-bord">Retounen sou tablo kont mwen</Link></p>
      </section>
    </main>
  </>;
}
