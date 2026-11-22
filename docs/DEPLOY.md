# Deplwaman KANÈ SA (v1.7.0-dev.0 — dev package; pa Production-ready) — etap pa etap

## 1. Supabase
1. Kreye yon pwojè Supabase. Nan *Authentication → URL Configuration*, mete URL sit la (Site URL) ak `https://ou-domen.com/auth/callback`.
2. Nan *SQL Editor*, egzekite nan lòd: `0001_kane_sa_core.sql`, `0002_kane_sa_control.sql`, `0003_kane_sa_admin_ops.sql`, `0004_kane_sa_ledger_compliance.sql`, epi `0005_kane_sa_automatic_withdrawals.sql`, epi `0006_kane_sa_withdrawal_hardening.sql`, `0007_kane_sa_platform_modules.sql`, epi `0008_kane_sa_real_money_scaffold.sql`.
3. Kreye kont ou nan app la, epi egzekite `supabase/first_admin.sql` (ak imel ou) pou vin premye admin.
4. Verifye: `select * from public.integrity_checks;` dwe bay 0 vyolasyon.

## 2. Varyab (`.env.local` pou lokal, secrets pou GitHub)
Gade `.env.example`: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_SITE_URL` (+ Firebase si ou itilize push).

## 3. Cloudflare Workers
- Secrets GitHub: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, ak tout varyab `NEXT_PUBLIC_*`.
- CI verifye kòd la otomatikman sou `push`/`pull_request`. Deploy Production rete separe, manyèl, epi li mande input `confirm_production=true`; workflow la itilize GitHub Environment `production`. Mete required reviewers sou environment sa a nan GitHub. Anvan deploy: `npm install`, `npm run verify`, `npm run cf:preview`; itilize deploy la sèlman apre tout apwobasyon yo.
- Ajoute domèn pèsonalize nan Cloudflare (Workers → Settings → Domains).

## 4. Anvan ou louvri bay piblik
- Kite `Content-Security-Policy-Report-Only` kèk jou, gade konsòl navigatè a, epi chanje l an `Content-Security-Policy` nan `next.config.ts` si pa gen erè.
- Pase tout pòtay `docs/GO_LIVE_GATES.md` (legal, BRH, KYC/AML, peman). **Pa kenbe lajan reyèl kliyan anvan sa.**
- Teste kòm kliyan, admin ak Kanèsa: depo → konfimasyon → quote retrè → otorizasyon otomatik oswa risk hold → peman tès → resi.

## 5. Sa app la gen kounye a
Otantifikasyon, plan, depo, quote retrè, otorizasyon otomatik pou demann ki pase kontwòl yo, risk hold, revizyon manual pou ka risk, KYC/AML fondasyon, ledger doub-antre, Kontwòl lajan, resi, admin/Kanèsa, audit, rate limiting, PWA ak CI/CD.

## 6. Espas lajan reyèl (prepare, pa aktive)
- Aplike `0008_kane_sa_real_money_scaffold.sql` apre migration 0007.
- `/admin/lajan-reel` montre estati provider yo ak kontè espas teknik yo.
- `money_rail_controls` fòse live/inbound/outbound/sandbox rete `false` epi kill switch la rete `true` atravè CHECK constraints.
- `compliance_settings.live_mode` pa ka chanje pou `true`; RPC admin lan refize demann aktivasyon.
- Payment intents ak payout attempts rete `staged`; provider adapters yo fail-closed epi yo pa fè apèl rezo. Webhook routes reponn 503.
- Pa gen API secret, merchant credential, checkout URL, webhook signature implementation oswa payout API ki antre nan pake a.

## 7. Sa ki rete (pa enkli)
Entegrasyon API MonCash/NatCash, sandbox ofisyèl, payout webhook, rekonsilyasyon ekstèn otomatik, KYC/AML operasyonèl konplè, odit endepandan, ak tès pilot.

## 8. Notifikasyon push (Firebase)
1. Firebase Console → Project settings → Service accounts → *Generate new private key*.
2. `wrangler secret put FIREBASE_SERVICE_ACCOUNT` (kole tout JSON la) ak `wrangler secret put SUPABASE_SERVICE_ROLE_KEY`. **Pa janm** mete yo nan `NEXT_PUBLIC_*`.
3. Kliyan an aktive notifikasyon nan dashboard la. Apre sa, konfimasyon/refi depo, otorizasyon otomatik, risk hold, revizyon ak peman retrè ka voye yon push. Tès FCM obligatwa.

## 9. Tès
`npm run verify` (typecheck, lint, Vitest ak build), `supabase test db` (pgTAP, mande Docker), `npm run e2e` (Playwright; mete `E2E_EMAIL`/`E2E_PASSWORD` pou flux konplè).
