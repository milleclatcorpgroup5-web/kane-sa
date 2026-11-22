# Lis anvan lansman

Sèvi ak `GO_LIVE_GATES.md` kòm lis konplè ak obligatwa. Kèk pwen prensipal:

- [ ] Revizyon legal/regilasyon ak kondisyon sèvis.
- [ ] Règleman vi prive, KYC/AML ak pwoteksyon done kote sa aplikab.
- [ ] Kontra ak API merchant ofisyèl MonCash/NatCash si yo sèvi.
- [ ] Sandbox, webhook, idempotency, refund, dispute ak reconciliation teste.
- [ ] Odit RLS, SQL RPC, API endpoints ak penetration test.
- [ ] Backup/restore, alerting, siveyans ak plan repons ensidan.
- [ ] Tès mobil, aksè, lang, HTG ak entènèt fèb.
- [ ] Pilot kontwole valide anvan nenpòt lajan reyèl.

## Nouvo modil v1.6
- [ ] Migration 0007 pase sou Supabase Development.
- [ ] Kliyan pa ka li dosye sipò lòt kliyan.
- [ ] Admin ka reponn epi chanje estati dosye sipò; audit parèt.
- [ ] Notifikasyon pa janm ekspoze bay yon lòt itilizatè; make kòm li fonksyone.
- [ ] Switch depo/retrè teste atravè UI, API ak insert dirèk nan bazdone.
- [ ] Rekonsilyasyon entèn pase sou done tès ki gen depo/retrè konfime.
- [ ] CSV verifye pou kantite/total yo ak limit dataset la.
- [ ] Restore drill ak odit sekirite endepandan fèt anvan pilot lajan reyèl.


## Nouvo verifikasyon v1.6.1
- [ ] Verifye Admin kapab filtre audit logs pa dat, action, entity ak actor.
- [ ] Verifye CSV la chape valè ki kòmanse ak `=`, `+`, `-` oswa `@`.
- [ ] Aktive maintenance_mode nan staging: kliyan pa ka POST/PUT/PATCH/DELETE; Admin ka kontinye; GET ak logout rete disponib.
- [ ] Verifye bann estati global la parèt pou kliyan ki konekte.


## v1.7.0-dev.0 — rails peman fèmen
- [ ] Aplike migration 0008 sou baz Supabase Development apre migrations 0001–0007.
- [ ] Verifye `/admin/lajan-reel` montre MonCash, NatCash ak bank kòm dezaktive.
- [ ] Verifye `money_rail_controls`: live/inbound/outbound/sandbox `false`, kill switch `true`.
- [ ] Verifye `admin_set_live_mode(true)` retounen erè epi okenn checkout/webhook pa trete.
- [ ] Pase tès pgTAP 0008 sou Supabase local/Development.
- [ ] Pa mete credentials ni pa debloke rails nan vèsyon sa a.
