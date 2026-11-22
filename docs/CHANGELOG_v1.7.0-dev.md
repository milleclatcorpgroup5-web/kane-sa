# KANÈ SA v1.7.0-dev.0 — Espas lajan reyèl (locked)

## Ajoute
- Migration SQL 0008 ak kontwòl hard-lock pou mouvman lajan.
- Rejis provider MonCash, NatCash ak bank san sekrè oswa kle prive.
- Tab payment intents ak idempotency key pou prepare workflow depo.
- Tab payout attempts ak idempotency key pou prepare workflow retrè.
- Webhook inbox ki konsève hash ak metadata sèlman, pa payload HTTP brit.
- Tab deklarasyon provider, liy statement, run rekonsilyasyon ak eksepsyon pou rekonsilyasyon ekstèn pita.
- Paj admin read-only `/admin/lajan-reel` ak API readiness.
- Endpoint preparasyon checkout ak webhook ki reponn 503 pandan tout rails rete fèmen.
- Provider adapter fail-closed; pa gen simulation peman, pa gen `fetch`, pa gen SDK provider.
- Tès Vitest pou hard-lock flags ak adapters; tès pgTAP pou constraints ak RPC admin.

## Sekirite
- `money_rail_controls` CHECK constraints fòse live/inbound/outbound/sandbox `false` ak kill switch `true`.
- Tout provider rete `enabled=false`, `environment='disabled'`, san credentials.
- `payment_intents` ak `payout_attempts` ka sèlman nan estati `staged` nan vèsyon sa a.
- `provider_webhook_inbox` fòse `signature_verified=false`, `processing_status='blocked'`.
- `compliance_settings.live_mode` pa ka vin `true`; `admin_set_live_mode(true)` refize aktivasyon.
- Tab operasyon provider yo pa gen write grants pou `authenticated`/`anon`; service role sèlman pou etap backend pita.

## Sa ki pa ajoute
- Pa gen API MonCash/NatCash, merchant credentials, payment checkout, payout API, webhook signature verification, SMS, KYC document upload oswa legal authorization.
- Pa gen lajan reyèl ki antre, sòti, oswa deplase nan vèsyon sa a.

## Verifikasyon
- Tès inite yo ajoute men runtime Vitest/TypeScript/Next/OpenNext dwe kouri nan CI.
- Tès pgTAP 0008 ajoute; yo dwe egzekite sou yon Supabase Development project anvan yo konsidere migration nan valide.
