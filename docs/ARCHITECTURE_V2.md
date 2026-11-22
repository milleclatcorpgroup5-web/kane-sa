# KANÈ SA v1.1 — Achitekti

**Prensip:** enfrastrikti solid anba, entèfas senp anwo. Kliyan wè 5 aksyon (Akèy, Kontwòl, Depo, Retrè, Istorik), tout règ finansye rete sou sèvè a.

| Kouch | Kisa li fè |
|---|---|
| UI (Next.js 15, mobil-an-premye) | Bare navigasyon anba, splash premye louvèti, skeleton `loading.tsx`, `error.tsx` |
| API (`app/api/*`) | Validasyon Zod (`lib/schemas.ts`), kle `Idempotency-Key` sou tranzaksyon, `/api/health` |
| Domèn (`lib/finance.ts`) | Fonksyon pi (rezime mwa, nòt sante finansye) ak tès Vitest |
| Baz done (Supabase) | RLS sou tout tab, fonksyon SQL sekirize, `integrity_checks` (admin) |
| Deplwaman | Cloudflare Workers (OpenNext), CI: typecheck, lint, test |

## Nouvo nan v1.1
- `/kontwol`: revni/depans pa kategori, bidjè mansyèl, nòt sante finansye (0-100).
- Migrasyon `0002_kane_sa_control.sql`: `transactions`, `budgets`, `integrity_checks`.
- Lòt bagay yo rete jan yo te ye: depo/retrè pase toujou pa admin.

## Pou aplike
1. Egzekite `0002_kane_sa_control.sql` nan Supabase (apre `0001`).
2. `npm install && npm test && npm run typecheck`.
3. Deplwaye ak `npm run cf:deploy`.

## Poko fèt
Ledger doub-antre pou depo/retrè, rate limiting, KYC/AML, i18n konplè, tès entegrasyon SQL, entèfas admin pou Kanèsa.

## Nouvo nan v1.2
- Migrasyon `0003`: `rate_limit_hit`, `admin_set_role`, `admin_assign_kanesa` (tout ak audit).
- `/admin/itilizate`: chanje wòl, asiyen Kanèsa, wè `integrity_checks`.
- `/resi/[id]`: resi depo enprimab. Similatè ekonomi sou paj dakèy la.
- Headers sekirite, `robots.ts`, `sitemap.ts`. Gade `docs/DEPLOY.md`.


## v1.4 — retrè otomatize nan nivo otorizasyon
- Migration `0005_kane_sa_automatic_withdrawals.sql` ajoute quote SQL ak klasifikasyon plan/frè.
- Plan san objektif itilize frè nòmal; plan objektif ki poko rive nan montan objektif la klase ijans; yon plan ki deja rive nan objektif la itilize frè nòmal.
- Demann ki pase kontwòl yo pran `approved` san apwobasyon admin; gwo montan/volim demann ka rete `pending` pou verifikasyon risk.
- Idempotency key, row lock plan, quote revalidation ak audit event pwoteje kont retry/double spend.
- `approved` vle di otorize nan app la, pa vle di provider la fin peye. Payout API ak rekonsilyasyon ekstèn poko konekte.

## Kouch peman — prepare, dezaktive (v1.7.0-dev.0)

`Money Rail Layer` se yon fwontyè separe ant lojik ekonomi/ledger entèn ak founisè ekstèn. Li genyen provider registry, payment intents inbound, payout attempts outbound, webhook inbox ak settlement staging pou rekonsilyasyon. Nan vèsyon sa a, okenn adapter pa rele founisè a; flags yo se `false`, kill switch la `true`, ak database CHECK constraints yo anpeche activation. `approved` rete yon otorizasyon entèn, pandan `paid` egzije prèv peman ekstèn. Paj `/admin/lajan-reel` se read-only. Yon release pita dwe retire verrou sèlman atravè migration revize apre provider sandbox, security, legal ak finans gates fin pase.
