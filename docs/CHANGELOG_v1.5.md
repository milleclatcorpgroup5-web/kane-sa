# KANÈ SA v1.5 — hardening candidate

## Chanjman prensipal
- Kenbe V2 kòm baz: Next.js, Supabase, Cloudflare Workers/OpenNext, Firebase opsyonèl.
- Mete Next.js 15 sou patch ki te aktyèl nan dat 19 novanm 2026 (`15.5.29`) epi mete OpenNext Cloudflare sou `1.20.17`.
- Ajoute migration `0006_kane_sa_withdrawal_hardening.sql`.
- Kalkil frè nòmal/ijans la baze sou balans aktyèl (depo mwens retrè peye). Balans disponib la toujou sèvi pou verifye si montan retrè a disponib apre rezèv.
- Mete quote rate limit la andedan SQL RPC a pou moun pa ka sote li lè yo rele Supabase dirèkteman.
- Fikse limit rate-limit yo pou chak route; kliyan pa ka pase kota diferan.
- Mete `search_path` vid pou RPC retrè ki te re-ekri nan migration 0006 epi kalifye referans schema yo.
- Ajoute tès regresyon pou rezèv retrè sou objektif ki deja rive ak kota rate-limit.
- Middleware a pa fè public pages tonbe lè Supabase Auth pa disponib; paj prive toujou fail-closed epi retounen sou koneksyon.
- Deploy workflow la vin manyèl pandan estabilizasyon an pou evite deploy production aksidantèl.

## Konpòtman retrè
1. Plan san objektif: frè nòmal.
2. Plan objektif ki poko rive selon balans aktyèl: frè ijans.
3. Plan objektif ki deja rive: frè nòmal.
4. Retrè ki pase verifikasyon: otorizasyon entèn otomatik (`approved`).
5. Risk hold: `pending`, revizyon admin.
6. `paid` sèlman apre peman ekstèn fin verifye; pa gen API payout MonCash/NatCash nan pake sa a.

## Limit
- Migration 0006 dwe aplike apre 0001–0005 sou yon Supabase Development/Test nouvo oswa backup.
- Tès SQL dwe pase sou PostgreSQL/Supabase reyèl avan deploy.
- Pakè npm pa t kapab enstale nan anviwònman konstriksyon an; se poutèt sa TypeScript/lint/Vitest/Next build pa make kòm pase.
- Sa a se yon kandida pou estabilizasyon MVP, pa yon deklarasyon production-ready ni yon apwobasyon pou jere lajan kliyan.
