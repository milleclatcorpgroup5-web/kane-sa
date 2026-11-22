# Peman — etap entegrasyon obligatwa

## Eta aktyèl
Pa gen API merchant MonCash/NatCash ki entegre. Fòm depo a kreye yon `deposit_request` nan baz done. Balans lan rete menm jan jiskaske admin verifye tranzaksyon an epi rele fonksyon SQL `admin_confirm_deposit`.

## Workflow depo ki an sekirite
1. Jwenn dokiman API ofisyèl, apwobasyon merchant, sandbox ak credentials nan men founisè a.
2. Backend kreye yon idantifyan demann peman inik epi anrejistre kantite lajan, HTG, itilizatè, plan, provider ak dat.
3. Itilizatè a peye dirèkteman nan workflow ofisyèl provider la.
4. Provider rele webhook backend la.
5. Backend verifye siyati webhook (si provider ofri l), otantisite orijin, transaction ID, montan, lajan, merchant ID, status ak referans request la.
6. Backend aplike idempotency: menm transaction ID pa kapab konfime de fwa.
7. Sèl apre verifikasyon an, depo a antre yon sèl fwa nan `deposits`.
8. Log ak alert pou webhook echwe, tranzaksyon ki pa matche, ak retry.

Pa janm konfime peman sou baz screenshot, mesaj SMS ki soti nan kliyan, oswa referans kliyan san verifikasyon sou sistèm provider la.

## Workflow retrè — otorizasyon otomatik, peman apa
1. Kliyan an chwazi yon plan ak montan. API `POST /api/retraits/quote` mande SQL pou kalkile balans disponib, kalite retrè, frè ak montan nèt.
2. Règ la pa soti nan navigatè a: plan san objektif sèvi ak frè nòmal; plan ki gen objektif men balans aktyèl la (depo mwens retrè peye) poko rive nan objektif la klase ijans; lè balans aktyèl la rive nan objektif la, frè nòmal la aplike. Rezèv sou demann pending/approved pa retire valè objektif ki te deja rive a.
3. Kliyan an wè montan brit, frè ak montan net epi li konfime. Backend verifye menm quote la ankò nan tranzaksyon SQL la; si règ/frè a chanje, demann lan pa antre epi kliyan an dwe rekalkile.
4. Pou demann ki pase verifikasyon yo, SQL otorize yo otomatikman (`status=approved`) epi rezève montan brit la. Kle idempotency anpeche yon retry re-kreye retrè a; lock sou plan an anpeche de retrè depanse menm balans lan.
5. Gwo montan oswa twòp demann nan 24 èdtan mete demann lan `pending` ak `authorization_mode=manual_review`; alèt AML ak audit log kreye. KYC toujou obligatwa sou montan ki depase limit KYC a.
6. Apre otorizasyon, lajan an dwe egzekite atravè yon provider oswa yon pwosesis operasyon ki otorize. Nan build sa a MonCash/NatCash API poko konekte; admin/operatè a sèlman make demann lan kòm peye apre li verifye peman an, avèk referans.
7. Lè estati a pase `paid`, ledger doub-antre a anrejistre retrè a. Rekonsilye peman ekstèn ak ledger la regilyèman.

**Limit kle:** build sa a otomatikman otorize kèk demann nan ledger aplikasyon an. Li pa voye HTG nan MonCash/NatCash oswa nan bank. Pa prezante `approved` kòm `paid` epi pa sèvi ak sa pou lajan kliyan jiskaske entegrasyon provider, rekonsilyasyon ak pòtay legal/sekirite yo fini.

## Kontwòl teknik ki obligatwa anvan API reyèl
- HMAC/signature validation oswa metòd ofisyèl provider la.
- Idempotency key ak constraint inik sou provider transaction ID.
- Rejou/retou webhook an sekirite; rate limit ak log.
- Double-entry ledger oswa sistèm tranzaksyon ki revize pa kontab/espesyalis finansye.
- Reconciliation, reversal, refund, dispute, timeout ak retry.
- Alèt sou diferans ant balans entèn ak sold provider.
- Sekrè API rete nan Cloudflare Secrets/Workers env, pa nan GitHub repo ni nan JavaScript kliyan.


## Espas lajan reyèl — v1.7.0-dev.0 (fèmen)

Pake a ajoute yon fondasyon provider, men li pa konekte okenn sèvis lajan reyèl:
- `money_rail_controls`: live, inbound, outbound ak sandbox rete `false`; `kill_switch` rete `true`. CHECK constraints nan PostgreSQL anpeche chanjman sa yo.
- `money_provider_accounts`: rejis MonCash, NatCash ak bank, san kle/secret. Tout provider rete `disabled`.
- `payment_intents`: espas idempotent pou depo/retrè; estati a rete `staged`. Trigger SQL la verifye provider, estati demann orijinal la ak montan brit/net la.
- `payout_attempts`: espas idempotent pou retrè; estati a rete `staged`. Trigger SQL la pèmèt preparasyon sèlman pou retrè `approved` epi li matche montan net ak metòd provider la.
- `provider_webhook_inbox`: pa kenbe body brit; signature verification rete false epi event status rete blocked.
- `provider_settlement_batches` / `provider_settlement_entries` / `provider_reconciliation_runs` / `provider_reconciliation_issues`: espas pou deklarasyon provider, run rekonsilyasyon ak eksepsyon pita; triggers verifye liy yo koresponn ak provider batch/run yo. Pa gen import/reconcile pipeline aktif.
- `/admin/lajan-reel` se paj sipèvizyon read-only. API checkout retounen 503; webhook route retounen 503. Adapter provider yo pa fè okenn `fetch` oswa apèl ekstèn.

Migration 0008 ranplase RPC `admin_set_live_mode(true)` ak yon fonksyon ki refize aktivasyon. `compliance_settings.live_mode` gen yon CHECK constraint ki fòse li rete false. Pou louvri sa pita, sa mande yon migration release apa, entegrasyon ofisyèl, tès sandbox, verifikasyon sekirite, rekonsilyasyon ak siyati legal/operasyonèl. Pa retire verrou yo manyèlman.

**Atansyon:** request depo ki deja nan app la rete demann manyèl; yon admin kapab konfime li apre verifikasyon manyèl, epi gen aksyon admin pou anrejistre yon payout offline. Sa pa konekte ak API provider, sa pa bay prèv otomatik, epi li pa dwe sèvi pou kliyan reyèl anvan pòtay legal/finansye/sekirite yo apwouve. `approved` sou retrè vle di otorizasyon entèn sèlman. Pake v1.7.0-dev.0 a bloke tout provider execution otomatik.
