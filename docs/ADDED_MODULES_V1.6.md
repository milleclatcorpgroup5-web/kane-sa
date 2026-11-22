# Modil ajoute nan KANÈ SA v1.6 Dev

Sa a se yon etap devlopman sou baz v1.5.1 RC1. Li pa yon deklarasyon ke aplikasyon an stable oswa pare pou jere lajan reyèl.

## 1. Kontwòl operasyon global

- `system_controls` kenbe switch pou aksepte/sispann nouvo demann depo ak nouvo demann retrè.
- Super Admin chanje switch yo atravè RPC `admin_set_system_controls`; aksyon an ekri nan `audit_logs`.
- Guard SQL sou `deposit_requests` ak `withdrawal_requests` anpeche kontoune switch la atravè API oswa yon insert dirèk.
- Switch retrè a pa anile, pa rejte epi pa peye demann ki te deja kreye yo. Li sèlman sispann nouvo demann.
- Mesaj estati piblik la limite a 320 karaktè.

## 2. Sant sipò

- Kliyan kreye dosye sipò atravè `create_support_ticket`.
- Kliyan ka wè sèlman pwòp dosye ak mesaj li yo; Admin ka wè tout dosye.
- Mesaj yo append-only pou itilizatè nòmal. Pa gen nòt entèn nan vèsyon sa a.
- Admin mete estati a ajou epi reponn atravè `admin_update_support_ticket`; aksyon admin lan antre nan audit.
- Rate limit: 5 nouvo dosye pa èdtan; 20 mesaj kliyan pa èdtan.
- Pa mande kliyan voye PIN, modpas, OTP oswa detay idantite sansib nan mesaj sipò.

## 3. Bwat notifikasyon

- Tab `user_notifications` konsève mesaj notifikasyon anndan aplikasyon an.
- Trigger baze done pwodui notifikasyon pou demann depo, depo konfime/rejte, demann retrè, ak chanjman estati retrè.
- Kliyan ka li pwòp notifikasyon yo epi make youn kòm li atravè `mark_notification_read`.
- Push Firebase rete yon chanèl opsyonèl separe; notifikasyon anndan app la pa mande sekrè Firebase.

## 4. Analiz ekonomi pèsonèl

- `/konsèy-finansye` kalkile pwogrè objektif, kontribisyon prevwa ak estimasyon tan.
- Kalkil yo deterministik; pa gen okenn done ki voye bay yon LLM oswa sèvis AI ekstèn.
- Forecast la se estimasyon senp sou kontribisyon prevwa. Li pa enterè, rentabilité ni garanti.

## 5. Rekonsilyasyon ak rapò

- `/admin/rekonsilyasyon` montre kontrol ledger entèn: balans negatif, ledger ki pa balanse, depo/retrè ki manke antre kontab ak diferans balans/ledger.
- `/admin/rapo` ak CSV bay total agregasyon aplikasyon.
- Sa yo poko rekonsilye ak rapò MonCash/NatCash/bank. Rekonsilyasyon ekstèn mande done provider verifye ak workflow ki poko la.

## 6. Sa ki pa enkli paske li bezwen patnè, kle oswa apwobasyon imen

- MonCash/NatCash merchant payout API, webhook signaturing ak sandbox credentials.
- KYC dokiman konplè, verifikasyon idantite ak AML operasyonèl.
- Entegrasyon SMS/email provider, FCM production credentials.
- Backup otomatik sou yon depo separe ak restore drill ki verifye.
- Odit sekirite endepandan, penetration test, legal/regulatory approval.
- AI jeneratif ekstèn. Modil konsèy la rete kalkil lokal senp.

## 7. Enstalasyon

Aplike `0007_kane_sa_platform_modules.sql` apre migration 0006. Pa egzekite `schema.sql` si ou deja aplike migrations yo. Pou baz Supabase tès vid, itilize migrations yo nan lòd.


## 8. Sant Audit ak ekspòtasyon

- `/admin/audit` bay filtè pou aksyon, kalite antite, aktè ak dat, avèk paj 50 antre.
- Ekspòtasyon CSV admin-only limite a 5,000 antre pa demann.
- CSV la chape siy ki ka aktive fòmil nan Excel/LibreOffice pou diminye risk CSV formula injection.
- Paj la li `audit_logs`; li pa modifye/siprime tras yo. Li pa agregasyon log Cloudflare/Supabase Auth oswa provider peman.

## 9. Aplikasyon mòd antretyen

- `app_settings.maintenance_mode` kounye a sèvi kòm yon write gate nan middleware pou demann `POST`, `PUT`, `PATCH` ak `DELETE` ki gen sesyon.
- Admin ka kontinye fè travay reparasyon; kliyan resevwa repons HTTP 503 pandan antretyen.
- Konsiltasyon (`GET`) ak dekoneksyon rete disponib.
- Sa pa ranplase yon kill switch nan provider payout, epi li pa bloke kliyan ki ta gen yon koneksyon dirèk deyò aplikasyon an. RLS, kontwòl SQL ak sekirite provider yo toujou obligatwa.


## 10. Limit wòl admin nan

- Vèsyon aktyèl la gen wòl `admin` kòm wòl privilejye global; li pa separe `super_admin`, `ops_admin`, `support_agent` oswa `compliance_officer` ankò.
- Pa bay wòl `admin` bay pèsonèl operasyon/sipò jis pou yo reponn kliyan. Pou kounye a, limit aksè a dwe fèt pa moun ou chwazi pou gen tout privilèj admin yo.
- Yon sistèm RBAC pi detaye mande yon migration separe, revizyon tout SQL `is_admin()`/RLS/RPC, API guards ak tès aksè negatif anvan li aktive.
