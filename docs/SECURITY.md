# Nòt sekirite

- Pa janm komèt `.env.local`, `.dev.vars`, service-role key, API secret, FCM service account oswa modpas nan GitHub.
- Fè MFA obligatwa pou GitHub, Cloudflare, Supabase ak kont Firebase admin.
- Kenbe Supabase Auth kòm sous otantifikasyon prensipal. Pa entwodui Firebase Auth san plan migrasyon klè.
- Revize RLS ak `SECURITY DEFINER` functions avèk yon espesyalis PostgreSQL/Supabase anvan pwodiksyon. Migration 0005 ajoute `quote_withdrawal` ak `request_withdrawal`; verifye yo ak tès konkou/idempotency anvan nenpòt pilot.
- Tout fonksyon `SECURITY DEFINER` dwe gen `search_path` fiks, validate `auth.uid()`/role, epi limite EXECUTE grants. Pa sipoze `approved` vle di payout fèt: `paid` mande prèv egzekisyon ekstèn ak referans verifye.
- Log yo pa dwe gen modpas, access tokens, detay peman konfidansyèl oswa twòp enfòmasyon sou ijans kliyan.
- Mete backup, retention, incident response, alerting ak rotation sekrè.
- Admin pa dwe itilize kont pataje. Chak admin dwe gen pwòp idantite li ak MFA.
- Fè revizyon legal/prive sou done telefòn, imel ak done ki gen rapò ak ijans.

Dokiman sa a pa ranplase yon security audit. Kòd la se yon MVP scaffold, pa yon sètifikasyon sekirite.
