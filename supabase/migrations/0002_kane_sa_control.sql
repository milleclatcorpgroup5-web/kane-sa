-- KANÈ SA 0002: kontwòl lajan pèsonèl (tranzaksyon, bidjè), idempotans ak kontwòl entegrite.
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('in','out')),
  category text not null check (category in ('manje','transpo','lekol','sante','kay','lot','revni')),
  amount numeric(14,2) not null check (amount > 0 and amount <= 100000000),
  note text check (char_length(note) <= 80),
  occurred_on date not null default current_date,
  idempotency_key text not null check (char_length(idempotency_key) <= 80),
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index if not exists transactions_user_date_idx on public.transactions (user_id, occurred_on desc);

create table if not exists public.budgets (
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('manje','transpo','lekol','sante','kay','lot')),
  monthly_limit numeric(14,2) not null check (monthly_limit > 0 and monthly_limit <= 100000000),
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);

alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
create policy "tx_select_own" on public.transactions for select to authenticated using (user_id = auth.uid());
create policy "tx_insert_own" on public.transactions for insert to authenticated with check (user_id = auth.uid());
create policy "tx_delete_own" on public.transactions for delete to authenticated using (user_id = auth.uid());
create policy "bud_select_own" on public.budgets for select to authenticated using (user_id = auth.uid());
create policy "bud_insert_own" on public.budgets for insert to authenticated with check (user_id = auth.uid());
create policy "bud_update_own" on public.budgets for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on public.transactions, public.budgets from anon;
grant select, insert, delete on public.transactions to authenticated;
grant select, insert, update on public.budgets to authenticated;

-- Kontwòl entegrite (admin sèlman): dwe toujou bay 0 vyolasyon.
create or replace view public.integrity_checks with (security_barrier = true) as
select c.* from (
  select 'negative_balance'::text as check_name, count(*)::int as violations from public.plan_balances where balance < 0
  union all select 'over_reserved', count(*)::int from public.plan_balances where available_balance < 0
  union all select 'duplicate_references', count(*)::int from (
    select verified_reference from public.deposits where verified_reference is not null group by 1 having count(*) > 1) d
) c where public.is_admin();
revoke all on public.integrity_checks from anon;
grant select on public.integrity_checks to authenticated;
