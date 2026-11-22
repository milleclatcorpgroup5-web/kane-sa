# Pòtay obligatwa anvan lansman ak lajan reyèl

Tout pwen sa yo dwe fini epi dokimante anvan KANÈ SA resevwa, kenbe, transfere oswa peye lajan kliyan.

## Legal ak konfòmite
- [ ] Avoka/regilatè lokal konfime ki lisans, enskripsyon ak otorizasyon ki nesesè pou modèl operasyon an.
- [ ] Règ sou kenbe lajan kliyan, segregasyon fon, bank/merchant, pwoteksyon konsomatè ak rapò konfime.
- [ ] KYC/AML, sanksyon, limit tranzaksyon, dosye ak rapò defini kote sa nesesè.
- [ ] Kondisyon sèvis, règleman vi prive, frè, retrè, ijans, plent ak ranbousman revize.
- [ ] Kontra ak MonCash/NatCash/bank/ajan otorize si sa nesesè.

## Finans ak operasyon
- [ ] Kont operasyon ak kont fon kliyan separe jan pwofesyonèl/regilasyon konseye.
- [ ] Pwosedi rekonsilyasyon chak jou ak responsab defini.
- [ ] Pwosedi pou tranzaksyon echwe, double, ranvèse, dispute ak ranbousman defini.
- [ ] Pwosedi apwobasyon doub pou retrè ki gen risk defini.
- [ ] Pwosedi repons ensidan ak kontak ijans ekri.

## Teknik ak sekirite
- [ ] API merchant nan sandbox pase tès; webhook signature ak idempotency teste.
- [ ] Odit RLS ak tout SQL RPC pa yon lòt ekspè.
- [ ] Penetration test endepandan; okenn P0/P1 rete louvri.
- [ ] Rate limits, abuse detection, WAF, alerting ak log prive konfigire.
- [ ] Backup otomatik, restore drill ak retansyon defini.
- [ ] KMS/secrets, rotation, MFA obligatwa pou admin, ak least privilege.
- [ ] Chaj, disponiblite, recovery point/time ak plan kont pann teste.
- [ ] Siveyans balans ak rekonsilyasyon verifye.

## Pwodwi ak sipò
- [ ] Tès fen-a-fen signup, reset modpas, plan, depo, retrè, admin, Kanèsa ak mobil.
- [ ] Frè yo klè anvan kliyan konfime.
- [ ] Resi tranzaksyon, sipò kliyan, plent ak kontestasyon mache.
- [ ] Aksesibilite, lang, lè lokal, HTG ak fòma kantite teste.
- [ ] Règ notifikasyon ak konsantman itilizatè verifye.
- [ ] Android/iOS package ak store compliance fini si app mobil obligatwa.

## Payment rails ak lajan reyèl
- [ ] MonCash/NatCash/bank partner agreement ak merchant account verifye.
- [ ] Sandbox depo ak payout pase tès end-to-end; API docs ak kontra founisè a konfime.
- [ ] Webhook authentication/signature, replay protection ak event idempotency teste.
- [ ] Payout success sèlman apre prèv provider; timeout/unknown/reversal/dispute gen pwosedi.
- [ ] Settlement statement import ak daily external reconciliation teste sou echantiyon verifye.
- [ ] Secrets nan secret manager, rotation ak access restrictions konfime.
- [ ] Mòd aktivasyon an fèt atravè release migration apa, review 2 moun, rollout etap pa etap ak kill switch verifye.

## Pilot
- [ ] Pilot fèmen san lajan reyèl oswa ak fon tès legalman apwouve.
- [ ] Limit tranzaksyon ak kont pilot defini.
- [ ] Tout rezilta pilot, erè ak mezi korektif siyen.

## Kote chak pòtay gen sipò nan app la (v1.3)
Sa a se zouti teknik, **pa konsèy legal**. Avoka ak regilatè yo deside ki pwosedi ki obligatwa.
- Pòtay yo nan `/admin/conformite`: checklist la pa sifi pou aktive mòd reyèl. Nan v1.7.0-dev.0, mòd lajan reyèl la **hard-locked nan SQL ak kòd**; `admin_set_live_mode(true)` refize aktivasyon menm si tout pòtay make fini.
- KYC: fòm `/kyc`, revizyon admin, retrè ki depase `kyc_threshold` bloke san KYC verifye (trigger SQL).
- AML: alèt otomatik pou gwo montan ak twòp demann nan 24h, revizyon admin.
- Ledger doub-antre append-only, ak kontwòl `ledger_vs_balance_mismatch` nan `integrity_checks`.
- Poko kouvri: foto dokiman, rapò bay otorite, lis sanksyon, API MonCash/NatCash (pou apre).
