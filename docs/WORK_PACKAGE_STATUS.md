# KANÈ SA v1.6.1-dev.1 — estati preparasyon

## Sa pake a gen ladan l
- Tout aplikasyon Next.js ki te nan baz V2 a: paj kliyan, admin, Kanèsa, routes API ak konpozan.
- Supabase Auth, PostgreSQL, RLS, SQL RPC, ledger, KYC/AML fondasyon ak audit.
- Senk migrasyon orijinal 0001–0005 ak migration 0006 pou hardening retrè/rate-limit.
- Cloudflare Workers + OpenNext, GitHub Actions CI, deplwaman manyèl, Firebase push opsyonèl.
- Tès Vitest, Playwright ak pgTAP.
- Nouvo modil: switch operasyon ak enforcement DB, support desk, notifications inbox, financial insights, global reports, internal reconciliation, Sant Audit, CSV export ak maintenance write gate.
- Dokiman achitekti, sekirite, peman, deplwaman ak pòtay lansman.

## Verifikasyon lokal ki fèt
- ZIP baz la te ekstrè epi estrikti aplikasyon/API/migration yo te enspekte.
- 103 fichye TypeScript/TSX pase parser syntax la; 0 syntax diagnostics (apre addendum v1.6.1-dev.1).
- `package.json` valid JSON; workflow GitHub Actions valid YAML.
- Snapshot `supabase/schema.sql` gen migrations 0001–0007; migration 0007 gen kantite delimiter `$$` ki balanse.
- `npm install --no-audit --no-fund` te depase limit tan anviwònman an apre de esè.
- San dependencies pa posib pou konfime `npm run typecheck`, `npm run lint`, Vitest oswa `next build`.
- Pa gen PostgreSQL/Supabase local runtime disponib; pgTAP/migrations yo pa te egzekite.

## Etap obligatwa anvan nou rele li stable
1. Enstale dependencies sou òdinatè/GitHub Actions epi kreye `package-lock.json` avèk `npm install`.
2. Pase `npm run verify` san okenn erè.
3. Aplike 0001–0007 sou yon pwojè Supabase Development/Test apa.
4. Pase `supabase test db` ak tout assertions pgTAP yo.
5. Pase E2E pou kliyan, admin ak Kanèsa sou done tès.
6. Verifye sekirite RLS, RPC, middleware, roles, idempotency, doub demann ak balans rezève.
7. Fè restore drill, tès chaj, odit sekirite endepandan ak validasyon legal/operasyonèl.
8. Pa pèmèt lajan reyèl avan provider payout/deposit ak webhook/reconciliation yo fin devlope epi pase tès sandbox.

**Eta aktyèl: v1.6.1-dev.1 (development package); syntax/source checks limite pase, men full build/SQL/E2E pa verifye; pa rele li stable oswa Production-ready.**

## Nouvo modil devlopman
- Migration 0007 ekri epi ajoute nan `supabase/schema.sql`; li poko egzekite sou yon PostgreSQL/Supabase runtime.
- Nouvo routes/paj TypeScript ak tès inite ajoute; typecheck/lint/build/E2E pou nouvo modil yo poko pase.
- Pa rele v1.6.1-dev.1 stable: li se yon dev package jiskaske CI, SQL/pgTAP ak E2E reyisi.


## Addendum v1.6.1-dev.1
- Ajoute Sant Audit admin, filtre/pagination, CSV export, bann estati global ak maintenance-mode write gate nan middleware.
- Pa gen entegrasyon provider oswa konfigirasyon Production ki ajoute.
- Pake a toujou DEV, pa rele li stable/Production-ready jiskaske tout tès quality gate ak tès sou Supabase/Cloudflare reyisi.


## Addendum v1.7.0-dev.0
- Prepare espas lajan reyèl la: provider registry, intents, payout attempts, webhook inbox ak settlement staging.
- Tout mouvman lajan rete dezaktive pa default ak pa constraint SQL; mòd reyèl pa ka aktive nan admin.
- Admin gen yon paj read-only pou wè estati provider yo.
- Pa gen MonCash/NatCash API key, SDK, webhook verification oswa peman reyèl ajoute.
- Tès lojik pou hard lock/adapter ajoute; tès runtime Next.js, PostgreSQL, Supabase ak Cloudflare rete pou fèt.

## Verifikasyon v1.7.0-dev.0
- Parser syntax sou 114 TS/TSX: 0 erè.
- Strict TypeScript check pase pou money flags/provider adapter core.
- JSON, YAML ak snapshot SQL parse/marker checks pase.
- npm dependency install timeout; full app typecheck/lint/test/build pa valide.
- PostgreSQL/pgTAP pa kouri; migration 0008 poko validate sou yon Supabase Development project.
