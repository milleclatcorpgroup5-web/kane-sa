# KANÈ SA v1.4 — sa ki chanje

## Règ retrè
- Kliyan an jwenn yon quote sou sèvè anvan konfimasyon: montan brit, frè, montan nèt, kategori ak kondisyon KYC/risk.
- Plan san objektif pran frè nòmal. Plan ki gen objektif men balans disponib la poko rive nan objektif la klase ijans. Si objektif la deja rive, frè nòmal la aplike.
- Frè yo dezaktive pa default; se admin ki ka modifye pousantaj yo, apre règleman frè yo fin klè.
- Demann ki pase kontwòl yo jwenn otorizasyon otomatik nan app la. Gwo montan oswa vitès demann ka mete yon hold pou revizyon risk.

## Backend ak sekirite
- Nouvo RPC `quote_withdrawal` ak nouvo `request_withdrawal` nan migration 0005.
- Verifikasyon quote la repete sou sèvè nan moman konfimasyon; kliyan pa ka fòse kalite retrè oswa pousantaj frè.
- Lock sou plan an pou pwoteje balans kont demann an menm tan.
- Idempotency key pou retry san double request.
- Rate limit 5 demann retrè nan 5 minit pa itilizatè; 30 kalkil quote pa minit.
- Gwo montan/volim demann ka rete `pending` ak `authorization_mode=manual_review`; alèt AML ak audit log kontinye.
- KYC threshold kontinye aplike.
- Admin pa apwouve chak retrè ankò; li revize ka ki gen risk epi make peman kòm `paid` apre li fin verifye peman ekstèn nan.

## UI/UX
- Fòm retrè a montre davans montan brit, frè, montan net, klasifikasyon ak bezwen KYC/risk.
- Istorik kliyan ak dashboard admin separe otorizasyon otomatik ak revizyon sekirite.

## Sa ki toujou pa fèt
- MonCash/NatCash payout API ak webhook pa konekte. `approved` pa vle di `paid`.
- KYC/AML legal/operasyonèl, BRH/avoka, segregasyon fon, odit ak rekonsilyasyon ekstèn rete pòtay obligatwa.
- ZIP sa a se yon baz travay pou tès, se pa yon apwobasyon pou resevwa oswa voye lajan reyèl.
