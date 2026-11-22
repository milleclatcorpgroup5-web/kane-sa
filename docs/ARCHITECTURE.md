# Achitekti KANÈ SA

```text
Navigatè / telefòn
      |
      v
Next.js App Router (Cloudflare Workers + OpenNext)
      |
      +---- Supabase Auth: session, imel, modpas
      |
      +---- Supabase PostgreSQL: profiles, savings_plans,
      |     deposit_requests, deposits, withdrawal_requests,
      |     app_settings, push_tokens, audit_logs
      |          |
      |          +---- RLS + SQL RPC + audit trail
      |
      +---- Firebase Cloud Messaging (opsyonèl)
      |
      +---- API merchant MonCash/NatCash (pa konekte nan MVP)
```

## Sous prensipal done
Supabase PostgreSQL se sèl sous verite pou kont, plan, depo, retrè ak balans. Pa kopye dosye finansye yo nan Firebase. Firebase la se pou notifikasyon push web opsyonèl.

## Balans
- `deposits` gen sèlman depo ki te konfime.
- `plan_balances.balance` = total depo konfime mwens retrè ki make kòm peye.
- `plan_balances.available_balance` = balans aktyèl mwens retrè an atant, apwouve oswa deja peye.
- Yon demann depo pa antre nan balans anvan admin konfime li.
- Yon retrè pa retire lajan nan balans lan anvan li peye, men montan li rezève nan montan disponib.

## Privilèj
- `kliyan`: wè ak modifye pwofil pa li, kreye plan pa li, kreye demann depo, mande retrè pa SQL RPC.
- `kanesa`: li plan ak dosye kliyan ki asiyen anba li.
- `admin`: revize peman/retrè, paramèt aplikasyon ak audit log.
- Wòl yo pa chwazi nan enskripsyon. Se operasyon prive admin/SQL ki bay wòl.

## Cloudflare
OpenNext adapte Next.js 15 pou Cloudflare Workers. `npm run dev` se dev server Next; `npm run cf:preview` sèvi pou teste build nan Worker runtime anvan deploy.

## Dokiman ofisyèl
- Cloudflare OpenNext adapter: https://developers.cloudflare.com/workers/framework-guides/web-apps/opennext/
- Firebase Cloud Messaging web: https://firebase.google.com/docs/cloud-messaging/web/get-started
- Supabase SSR auth: https://supabase.com/docs/guides/auth/server-side/nextjs

Remak: dokiman Cloudflare aktyèl la mete aksan sou `vinext` pou nouvo pwojè; depo sa a kenbe Next.js 15 + OpenNext kòm chimen li konfigire. Verifye konpatibilite ak rekòmandasyon Cloudflare yo anvan deploy production.
