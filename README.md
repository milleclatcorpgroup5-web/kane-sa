# KANÈ SA v1.7.0-dev.0 — Project Kit

KANÈ SA se yon aplikasyon web mobil-an-premye pou **ekonomi pèsonèl**. Chak moun kenbe pwòp plan ekonomi pa li. Pa gen ekonomi kolektif/rasanbleman kolektif nan vèsyon sa a.

> **Eta pwojè a:** kit MVP pou devlopman, tès ak preparasyon. Li gen kont kliyan, plan ekonomi, depo, retrè ak klasifikasyon/frè ki kalkile nan SQL, otorizasyon entèn otomatik pou demann ki pase kontwòl risk yo, hold pou ka ki bezwen revizyon, espas Kanèsa, dashboard admin, KYC/AML fondasyon, ledger ak audit. Li **pa** pare pou lajan reyèl: tout rails inbound/outbound/sandbox rete fèmen ak verrou SQL; pa gen API MonCash/NatCash, webhook oswa payout ki konekte; otorizasyon retrè nan app la pa vle di lajan an peye; KYC/AML ak pwosesis legal yo pa konplè; odit sekirite endepandan poko fèt.

## Fonksyon ki deja nan kòd la

### Espas kliyan
- Enskripsyon ak non, telefòn, imel ak modpas.
- Koneksyon, dekoneksyon, reset modpas.
- Kreye plan ekonomi ak objektif oswa san objektif.
- Kontribisyon prevwa ak frekans kòm enfòmasyon gid (yo pa obligasyon).
- Demann depo MonCash, NatCash, lajan kach, bank oswa lòt metòd.
- Demann retrè ak quote frè anvan konfimasyon.
- Plan san objektif: frè nòmal; plan objektif ki poko rive: retrè ijans ak frè ijans; objektif ki deja rive: frè nòmal.
- Demann ki pase kontwòl yo jwenn otorizasyon otomatikman; gwo montan oswa vitès demann mete yo an atant pou revizyon sekirite.
- Balans ki kalkile sou depo admin konfime yo sèlman; demann an atant/otorize rezève montan brit la.
- Istorik demann depo, depo konfime ak retrè.
- Aktivasyon notifikasyon navigatè Firebase (opsyonèl, apre konfigirasyon).
- Bwat notifikasyon anndan app la pou evènman depo/retrè; make kòm li.
- Sant sipò: kliyan louvri dosye, voye mesaj, admin jere estati epi reponn.
- Konsèy finansye ak forecast detèministik ki kalkile sou pwòp plan kliyan an; pa gen LLM ekstèn.
- Mesaj estati operasyon ak switch Super Admin pou bloke nouvo demann depo/retrè nan nivo bazdone.

### Espas Kanèsa
- Konsilte plan kliyan admin mete anba sipèvizyon Kanèsa a.
- Konsilte balans ak montan disponib.
- Nan vèsyon sa a, Kanèsa pa konfime depo ni apwouve/paye retrè.

### Dashboard admin prive
- Lis kont resan, demann depo ak demann retrè.
- Konfime/rejte demann depo.
- Revize sèlman retrè ki rete an atant pou risk oswa legacy; fè rekonsilyasyon epi make retrè kòm peye apre peman fèt.
- Paramèt frè nòmal/ijans (dezaktive pa defo) ak mòd antretyen.
- Jounal audit pou aksyon finansye admin yo.
- Kontwòl global pou sispann nouvo demann depo oswa retrè; demann ki deja egziste yo pa anile.
- Jesyon dosye sipò kliyan ak repons vizib pou kliyan.
- Rapò global CSV, Sant Audit ak kontwòl rekonsilyasyon ledger entèn.
- Mòd antretyen bloke demann API ki modifye done pou kliyan; Admin rete kapab antre pou reparasyon. Itilizatè yo toujou kapab konsilte done yo ak dekonekte.
- Wòl admin/Kanèsa pa ka chwazi nan fòm enskripsyon piblik la.
- Nan vèsyon sa a, `admin` se wòl privilejye global la; pa gen separasyon teknik ant Super Admin ak ajan operasyon/sipò. Bay wòl sa a sèlman ak moun ki merite tout dwa admin.

### Sekirite nan baz done
- Supabase Auth jere modpas yo; modpas pa estoke an tèks klè nan app la.
- Row Level Security (RLS) sou tab prensipal yo.
- Fonksyon SQL sekirize pou quote retrè, otorizasyon otomatik, hold risk, revizyon admin, konfimasyon depo ak make kòm peye.
- Sèl depo konfime admin antre nan balans.
- Retrè yo rezève montan an pandan yo an atant oswa apwouve pou evite mande menm lajan an de fwa.
- Lock sou plan, idempotency pou retry, rate limit, audit log ak ledger doub-antre append-only.
- Pa gen kle service-role ni sekrè peman nan navigatè a.

## Achitekti

- **GitHub**: depo kòd, vèsyon ak GitHub Actions.
- **Cloudflare Workers**: deplwaman aplikasyon Next.js ak OpenNext adapter. Pwojè sa a rete sou Next.js 15; Cloudflare gen lòt chwa adapter pou Next.js 16+.
- **Supabase**: otantifikasyon ak PostgreSQL kòm sous prensipal verite pou kont, plan ak dosye finansye.
- **Firebase**: sèlman pou notifikasyon push web opsyonèl nan fondasyon sa a. Pa itilize Firebase kòm dezyèm baz done balans/transactions.
- **MonCash/NatCash**: poko konekte. Entegrasyon an dwe fèt ak API ofisyèl, kont merchant ak webhook verifye.

## 1. Sa ou bezwen

- GitHub account.
- Cloudflare account (Workers aktive).
- Supabase account.
- Firebase account sèlman si ou vle notifikasyon push.
- Node.js 20 LTS oswa pi resan ak npm.

## 2. Mete pwojè a sou GitHub

1. Telechaje ZIP sa a epi ekstrè li.
2. Ale nan GitHub epi kreye yon nouvo repository, pa egzanp `kane-sa`.
3. Upload tout sa ki anndan folder `KANE_SA` nan root repository la (pa upload fichye ZIP la poukont li).
4. Commit sou branch `main`.
5. GitHub Actions verifye kòd la otomatikman sou `push` ak `pull_request`. Deploy Production separe, manyèl, epi mande konfimasyon ak apwobasyon nan GitHub Environment `production`.

Sou yon òdinatè ki gen Git, ou ka fè:

```bash
git init
git add .
git commit -m "Initial KANE SA application"
git branch -M main
git remote add origin https://github.com/USERNAME/kane-sa.git
git push -u origin main
```

Ranplase `USERNAME` ak non kont GitHub ou. Pa janm ajoute `.env.local`, sekrè, modpas oswa service-account JSON nan GitHub.

## 3. Konfigire Supabase

1. Kreye yon nouvo pwojè Supabase.
2. Louvri **SQL Editor**.
3. Sou yon pwojè Supabase vid, egzekite migrasyon yo youn apre lòt nan SQL Editor: `0001_kane_sa_core.sql`, `0002_kane_sa_control.sql`, `0003_kane_sa_admin_ops.sql`, `0004_kane_sa_ledger_compliance.sql`, epi `0005_kane_sa_automatic_withdrawals.sql`, epi `0006_kane_sa_withdrawal_hardening.sql`, epi `0007_kane_sa_platform_modules.sql`, epi `0008_kane_sa_real_money_scaffold.sql`. Pa sote okenn migration. `supabase/schema.sql` se snapshot konbine pou enstalasyon manyèl; li gen menm chanjman yo jiska migration 0008. Pa egzekite li anplis migrations yo.
4. Ale nan **Project Settings → API** epi pran Project URL ak anon/publishable key.
5. Nan root pwojè a, kopye `.env.example` pou `.env.local` epi ranpli:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY
```

6. Nan Supabase **Authentication → URL Configuration**, mete URL lokal la `http://localhost:3000` pandan devlopman, epi ajoute URL Cloudflare production lan nan Redirect URLs.
7. Konfigire SMTP/imel pou verifikasyon imel ak reset modpas anvan tès kliyan reyèl.

**Pa mete `SUPABASE_SERVICE_ROLE_KEY` nan `NEXT_PUBLIC_` oswa nan dosye GitHub.** Fondasyon sa a sèvi ak session kliyan + RLS ak fonksyon SQL pou aksyon ki mande dwa admin.

### Kreye premye admin lan

1. Kreye kont ou nòmalman atravè `/inscription`.
2. Nan Supabase → Authentication → Users, kopye UUID kont ou.
3. Nan SQL Editor, verifye UUID a epi egzekite:

```sql
update public.profiles
set role = 'admin'
where id = 'METE-UUID-ADMIN-LA-ISIT';
```

4. Dekonekte epi rekonekte. Louvri `/admin`.

### Kreye yon kont Kanèsa epi bay li plan kliyan

1. Fè moun Kanèsa a kreye kont atravè `/inscription`.
2. Verifye UUID li nan Supabase Auth.
3. Bay li wòl `kanesa`:

```sql
update public.profiles
set role = 'kanesa'
where id = 'UUID-KANESA';
```

4. Mete plan kliyan an anba sipèvizyon Kanèsa a:

```sql
update public.savings_plans
set kanesa_id = 'UUID-KANESA'
where id = 'UUID-PLAN-KLIYAN';
```

Fè aksyon sa yo sèlman nan SQL Editor pa yon moun ki gen otorizasyon. Pa bay piblik la aksè pou chanje wòl.

## 4. Kouri lokalman

```bash
npm install
npm run dev
```

Louvri `http://localhost:3000`. Pou verifye kòd:

```bash
npm run typecheck
npm run lint
npm run build
```

Pa gen `package-lock.json` nan ZIP sa a paske anviwònman konstriksyon an pa t kapab telechaje pakè npm yo. Premye `npm install` sou òdinatè w ap kreye li; ajoute `package-lock.json` nan GitHub apre enstalasyon an reyisi. GitHub Actions nan ZIP la itilize `npm install` jiskaske lockfile la ajoute. Lè enstalasyon lokal la reyisi, konsève `package-lock.json` nan repository la epi ajiste workflow yo pou itilize `npm ci`.

## 5. Deplwaye sou Cloudflare Workers

Pwojè sa a konsève Next.js 15 + OpenNext pou limite chanjman sou baz V2 a. OpenNext sipòte dènye minor/patch Next.js 15; Cloudflare kounye a rekòmande vinext pou nouvo aplikasyon, men li se yon chanjman migrasyon apa ki dwe pase tès konpatibilite avan nou fè li.

1. Konekte GitHub nan Cloudflare Workers & Pages.
2. Chwazi repository `kane-sa`.
3. Pou deplwaman manyèl atravè GitHub Actions, konfigire GitHub Secrets yo:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - Firebase secrets yo sèlman si Firebase aktive.
4. Nan Cloudflare, mete menm anviwònman public Supabase/Firebase yo nan Worker **Settings → Variables and Secrets** pou runtime.
5. Kouri `npm run verify` epi lokalman `npm run cf:preview` anvan production. Workflow deploy la se manyèl (`workflow_dispatch`) pandan tès ak estabilizasyon; pa deplwaye sou production jiskaske `docs/QUALITY_REPORT.md` ak `docs/GO_LIVE_GATES.md` pase.
6. Mete custom domain ou nan Cloudflare epi ajoute li nan Supabase Auth Redirect URLs.

`wrangler.jsonc` deja fikse non Worker la kòm `kane-sa-web`. Chanje non sa a si non an deja itilize sou kont Cloudflare ou.

## 6. Firebase notifikasyon (opsyonèl)

1. Kreye yon Firebase Web App nan Firebase Console.
2. Aktive Firebase Cloud Messaging.
3. Mete Web Push certificate/VAPID key.
4. Antre valè piblik yo nan `.env.local` epi nan Cloudflare/GitHub Actions secrets yo:
   - `NEXT_PUBLIC_FIREBASE_API_KEY`
   - `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
   - `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
   - `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
   - `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
   - `NEXT_PUBLIC_FIREBASE_APP_ID`
   - `NEXT_PUBLIC_FIREBASE_VAPID_KEY`
5. Ranplase valè `YOUR_FIREBASE_...` nan `public/firebase-messaging-sw.js` ak konfigirasyon pwojè Firebase la.
6. Aplike migration SQL la pou tab `push_tokens` epi teste sou HTTPS.

Kòd la kapab anrejistre token epi itilize Firebase Cloud Messaging HTTP v1 sou backend si `FIREBASE_SERVICE_ACCOUNT` ak `SUPABASE_SERVICE_ROLE_KEY` byen mete kòm Cloudflare Secrets. Pa mete private key la nan navigatè a. Tès voye push yo dwe fèt apre sekrè yo fin konfigire.

## 7. Depo, retrè ak peman — sa ki enpòtan

- Demann depo a se yon demann pou administrasyon verifye; li pa vle di lajan an antre.
- MonCash, NatCash, bank ak cash pa konekte ak API otomatik nan vèsyon sa a.
- Admin dwe verifye tranzaksyon an nan sous ofisyèl la anvan li konfime depo a. Pou MonCash/NatCash/bank, kòd la mande yon referans tranzaksyon verifye.
- Demann retrè kalkile frè/klasifikasyon sou sèvè. Lè risk pa leve drapo, li jwenn `approved` otomatikman epi rezève montan brit la; ka risk rete `pending` pou admin revize. Apre peman ekstèn fèt, admin/operatè a make li kòm `paid` ak referans.
- Frè yo 0% epi dezaktive pa defo. Pa aktive frè san yo pa defini klèman ak legalman, kominike ak kliyan, epi valide règleman yo.
- Pa itilize screenshot kòm sèl prèv peman.

Gade `docs/PAYMENTS.md`, `docs/GO_LIVE_GATES.md`, `docs/ADDED_MODULES_V1.6.md`, `docs/OPERATIONS_RUNBOOK.md` ak `docs/QUALITY_REPORT.md` anvan nenpòt tès ki manyen lajan.

## 8. Sa ki poko fini / limit aktyèl

1. Entegrasyon API merchant MonCash/NatCash ak webhook verifye.
2. Pwosesis peman retrè reyèl ak rekonsilyasyon bank/telefòn.
3. Konplete KYC/AML, limit kont, verifikasyon idantite, siveyans ak pwoteksyon done selon konsèy legal.
4. Notifikasyon Firebase sou sèvè mande sekrè FCM/Supabase ki konfigire epi tès livrezon sou aparèy reyèl.
5. Jesyon payout, rekonsilyasyon, kontestasyon ak zouti operasyon finansye ki konplè.
6. Resi PDF/email, sipò kliyan, kontestasyon tranzaksyon ak retou lajan.
7. Backup/restore, siveyans, alerting, pwoteksyon kont abi, rate limiting/WAF ak tès chaj.
8. Odit sekirite endepandan, tès penetration ak revizyon dwa baz done.
9. Aplikasyon Android/iOS natif oswa wrapper, ak pwosesis piblikasyon store yo.

**Pa mete lajan kliyan nan sistèm nan jiskaske tout pòtay `docs/GO_LIVE_GATES.md` yo pase epi tout kondisyon legal/regilasyon yo konfime pa pwofesyonèl ki kalifye.**

## Mòd antretyen ak Sant Audit

- Mòd antretyen an bloke demann API ki modifye done pou itilizatè ki pa admin; admin rete kapab antre pou reparasyon. Konsiltasyon ak dekoneksyon rete disponib.
- `/admin/audit` pèmèt admin filtre jounal audit epi ekspòte jiska 5,000 antre CSV. Li pa ranplase log Cloudflare, Supabase Auth oswa provider peman.

## Estrikti dosye

```text
app/                    Paj kliyan, admin, Kanèsa ak API routes
components/             Konpozan UI
lib/                    Supabase, Firebase, verifikasyon ak fonksyon komen
supabase/migrations/    SQL baz done + RLS + fonksyon finansye
public/                 Manifest PWA ak Firebase service worker
.github/workflows/      CI ak deployment Cloudflare
wrangler.jsonc          Konfigirasyon Cloudflare Workers
open-next.config.ts     Konfigirasyon OpenNext
docs/                   Achitekti, peman, sekirite ak lansman
```

## v1.5 — estabilizasyon retrè ak sekirite
Gade `docs/PAYMENTS.md`, `docs/PRODUCT_RULES.md` ak migrations `0005`/`0006`. Nouvo migration sa a ajoute quote SQL, klasifikasyon frè selon plan, risk hold, otorizasyon otomatik, idempotency ak limit retrè. Aplike tout migrations yo nan lòd sou yon baz Supabase vid.

## Modil v1.6 Dev

Aplike migration `0007_kane_sa_platform_modules.sql` apre migration 0006. Li ajoute kontwòl operasyon, sipò kliyan, bwat notifikasyon, analiz ekonomi, rapò global ak rekonsilyasyon entèn. Detay: `docs/ADDED_MODULES_V1.6.md`.


## Espas lajan reyèl (v1.7.0-dev.0 — fèmen)
Migration `0008_kane_sa_real_money_scaffold.sql` prepare provider accounts, payment intents, payout attempts, webhook inbox ak settlement staging. `/admin/lajan-reel` montre eta yo. Tout flags rete fèmen pa constraint bazdone ak kòd; pa gen entegrasyon MonCash/NatCash aktif. Aplike migrations 0001 rive 0008 nan lòd sou yon pwojè Supabase Development vid. Gade `docs/PAYMENTS.md` ak `docs/GO_LIVE_GATES.md`.

## Espas lajan reyèl prepare, men fèmen

Nan v1.7.0-dev.0, nou mete baz teknik pou provider registry, payment intents, payout attempts, webhook inbox ak deklarasyon provider. Admin ka wè li nan `/admin/lajan-reel`. Tout mòd peman rete fèmen; `admin_set_live_mode(true)` bloke nan SQL, provider adapters pa fè apèl rezo, checkout/webhook endpoints reponn 503. Pa antre okenn API secret oswa merchant credentials nan pwojè a. Gade `docs/PAYMENTS.md`, `docs/GO_LIVE_GATES.md` ak `docs/CHANGELOG_v1.7.0-dev.md`.
