# KANÈ SA — plan backup ak rekiperasyon (runbook pou mete ann aplikasyon)

Dokiman sa a se yon plan travay, se pa prèv ke backup deja aktive.

## Sa pou mete an plas anvan pilot

- Aktive backup otomatik Supabase ki apwopriye ak plan sèvis la.
- Kenbe yon kopi backup chifre, separe ak pwojè prensipal la, avèk aksè limite.
- Defini RPO/RTO ak moun ki gen dwa deklare yon rekiperasyon.
- Kenbe sekrè nan password manager/secret manager; pa mete yo nan ZIP oswa Git.
- Dokimante retansyon, chifreman, aksè ak pwosedi efasman done.

## Restore drill

1. Kreye yon pwojè Supabase restore/test ki pa gen fon kliyan reyèl.
2. Restore backup la nan anviwònman izole.
3. Aplike/verifye migrations yo; kouri `supabase test db`.
4. Verifye kantite kont, plan, depo, retrè, ledger ak audit.
5. Louvri `admin_reconciliation_checks`; tout chèk kritike yo dwe eksplike.
6. Verifye login, RLS, API health, notifikasyon ak paj sipò.
7. Ekri dat, dire, rezilta ak nenpòt diferans.

Pa konsidere backup/restore kòm valide jiskaske yon egzèsis restore reyisi epi yon responsab siyen rezilta a.
