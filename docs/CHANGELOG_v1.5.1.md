# KANÈ SA v1.5.1 RC1 — estabilizasyon anplis

- Mete kle idempotency retrè yo anba advisory transaction lock pou retry konkiran pa ka kreye doub demann menm kle a.
- Valide kantite, kalite ak metòd retrè anvan rechèch idempotency.
- Normalize rezon retrè pou replay demann nòmal yo rete idempotent.
- Ajoute pgTAP assertion pou anpeche menm kle idempotency a sèvi ak yon lòt montan.
- Deploy Production vin mande konfimasyon boolean ak GitHub Environment `production`; konseye required reviewers.
- Mete workflow CI/deploy sou Node.js 22.
- Refresh `supabase/schema.sql` pou matche migration 0006.

## Limit RC1

Tès TypeScript syntax parse ak validation JSON/YAML pase nan anviwònman preparasyon an. Dependencies/npm install te time out, kidonk pa gen full typecheck, lint, Vitest, Next/OpenNext build oswa SQL/pgTAP/E2E runtime result. Se poutèt sa RC1 se yon kandida pou tès ak estabilizasyon, li pa yon deklarasyon stable oswa Production-ready.
