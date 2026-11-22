# KANÈ SA — gid operasyon ak ensidan

## Lè gen ensidan

1. Super Admin ouvri Dashboard Admin epi aktive switch ki koresponn lan pou sispann nouvo demann depo ak/oswa retrè.
2. Ekri yon mesaj piblik kout ki di sèvis la limite tanporèman; pa revele detay sekirite.
3. Pa efase dosye tranzaksyon, ledger oswa audit.
4. Konsève ID demann, lè UTC, referans founisè ak mesaj erè entèn yo.
5. Tcheke `/admin/rekonsilyasyon` ak lis AML; pa make okenn retrè kòm peye san prèv ki soti nan sous peman otorize a.
6. Louvri dosye sipò pou kliyan ki afekte yo. Pa mande PIN, modpas oswa OTP.
7. Fè revizyon teknik/operasyonèl; sèlman responsab otorize a ka reaktive switch yo apre tès.

## Ki sa switch yo fè

- `deposits_enabled = false`: bloke nouvo inserts nan `deposit_requests`.
- `withdrawal_requests_enabled = false`: bloke nouvo inserts nan `withdrawal_requests`.
- Yo pa anile depo ki deja konfime, retrè ki deja apwouve, ni peman ki poko rekonsilye.
- Yo pa bloke koneksyon oswa aksè istorik kliyan an.
- Mòd antretyen jeneral ki nan `app_settings` rete yon paramèt apa; pa sipoze li bloke tout paj/API.

## Eskalasyon

- Pwoblèm balans/ledger: sispann nouvo operasyon ki afekte yo, konsève done, kontakte responsab kontablite/teknik.
- Pwoblèm aksè oswa sispèk fwod: sispann demann ki afekte yo; verifye audit, sesyon ak idantite dapre pwosedi KYC.
- Pwoblèm founisè peman: pran prèv dirèk nan dashboard/API founisè a; pa baze konfimasyon sou screenshot kliyan sèlman.
