-- KANÈ SA v1.6.1-dev.1 — combined schema snapshot
-- Prefer running migrations in order via Supabase CLI or SQL Editor.
-- Do NOT run this file in addition to the individual migrations.



-- ===== BEGIN 0001_kane_sa_core.sql =====

-- KANÈ SA — fondasyon baz done. Kouri sou yon pwojè Supabase vid.
-- Lajan ki antre konte sèlman apre yon admin verifye tranzaksyon an.
create extension if not exists pgcrypto;

do $$ begin create type public.app_role as enum ('kliyan','kanesa','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.plan_frequency as enum ('daily','weekly','monthly','flexible'); exception when duplicate_object then null; end $$;
do $$ begin create type public.plan_status as enum ('active','paused','closed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.deposit_status as enum ('pending','confirmed','rejected'); exception when duplicate_object then null; end $$;
do $$ begin create type public.withdrawal_status as enum ('pending','approved','rejected','paid'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'kliyan',
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  phone text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  id int primary key default 1 check (id = 1),
  normal_withdrawal_fee_percent numeric(5,2) not null default 0 check (normal_withdrawal_fee_percent between 0 and 25),
  emergency_withdrawal_fee_percent numeric(5,2) not null default 0 check (emergency_withdrawal_fee_percent between 0 and 25),
  fees_enabled boolean not null default false,
  maintenance_mode boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.app_settings(id) values (1) on conflict (id) do nothing;

create table if not exists public.savings_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  kanesa_id uuid references public.profiles(id) on delete set null,
  title text not null default 'Plan ekonomi mwen' check (length(trim(title)) between 2 and 80),
  has_goal boolean not null default false,
  goal_amount numeric(14,2),
  planned_contribution numeric(14,2),
  frequency public.plan_frequency not null default 'flexible',
  status public.plan_status not null default 'active',
  start_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((has_goal and goal_amount is not null and goal_amount > 0) or (not has_goal and goal_amount is null)),
  check (planned_contribution is null or planned_contribution > 0)
);

create table if not exists public.deposit_requests (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.savings_plans(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  method text not null check (method in ('moncash','natcash','cash','bank','other')),
  amount numeric(14,2) not null check (amount > 0 and amount <= 10000000),
  customer_reference text,
  admin_note text,
  status public.deposit_status not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (customer_reference is null or length(customer_reference) <= 120),
  unique(id, plan_id, user_id)
);

create table if not exists public.deposits (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.savings_plans(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  deposit_request_id uuid not null unique,
  amount numeric(14,2) not null check (amount > 0),
  method text not null check (method in ('moncash','natcash','cash','bank','other')) ,
  verified_reference text,
  confirmed_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint deposits_request_matches_plan_user foreign key (deposit_request_id, plan_id, user_id) references public.deposit_requests(id, plan_id, user_id) on delete restrict
);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.savings_plans(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  kind text not null check (kind in ('normal','emergency')),
  reason_category text,
  reason_text text,
  gross_amount numeric(14,2) not null check (gross_amount > 0 and gross_amount <= 10000000),
  fee_percent numeric(5,2) not null default 0 check (fee_percent between 0 and 25),
  fee_amount numeric(14,2) not null default 0 check (fee_amount >= 0),
  net_amount numeric(14,2) not null check (net_amount >= 0),
  payment_method text check (payment_method in ('moncash','natcash','cash','bank')),
  payment_reference text,
  admin_note text,
  status public.withdrawal_status not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  paid_by uuid references public.profiles(id),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  check (kind <> 'emergency' or reason_category in ('medical','death','family_emergency','other')),
  check (round(fee_amount,2) = round(gross_amount * fee_percent / 100,2)),
  check (round(net_amount,2) = round(gross_amount - fee_amount,2))
);

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null default 'web' check (platform in ('web','android','ios')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_savings_plans_user on public.savings_plans(user_id, created_at desc);
create index if not exists idx_savings_plans_kanesa on public.savings_plans(kanesa_id) where kanesa_id is not null;
create index if not exists idx_deposit_requests_status on public.deposit_requests(status, created_at desc);
create index if not exists idx_withdrawal_requests_status on public.withdrawal_requests(status, created_at desc);
create index if not exists idx_deposits_plan on public.deposits(plan_id, created_at desc);
create unique index if not exists idx_deposits_provider_reference on public.deposits(method, verified_reference) where verified_reference is not null;
create unique index if not exists idx_withdrawal_provider_reference on public.withdrawal_requests(payment_method, payment_reference) where payment_reference is not null;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists plans_updated_at on public.savings_plans;
create trigger plans_updated_at before update on public.savings_plans for each row execute function public.set_updated_at();

create or replace function public.audit_settings_update()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'settings_updated','app_settings',new.id::text,jsonb_build_object('fees_enabled',new.fees_enabled,'maintenance_mode',new.maintenance_mode,'normal_fee_percent',new.normal_withdrawal_fee_percent,'emergency_fee_percent',new.emergency_withdrawal_fee_percent));
  return new;
end; $$;
drop trigger if exists audit_settings_after_update on public.app_settings;
create trigger audit_settings_after_update after update on public.app_settings for each row execute function public.audit_settings_update();

-- Kreye pwofil la otomatikman lè Supabase Auth kreye itilizatè a.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_name text;
begin
  v_name := coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1), 'Nouvo kliyan');
  insert into public.profiles(id, full_name, phone, role)
  values (new.id, left(v_name,120), nullif(trim(new.raw_user_meta_data->>'phone'), ''), 'kliyan')
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.profiles where id = auth.uid()
$$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin')
$$;

-- Prevente moun chanje pwòp role yo, menm si yo eseye atravè API.
create or replace function public.prevent_profile_privilege_escalation()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null and not public.is_admin() then
    raise exception 'Ou pa gen dwa chanje wòl kont sa a.';
  end if;
  if new.id is distinct from old.id then raise exception 'ID pwofil la pa ka chanje.'; end if;
  return new;
end; $$;
drop trigger if exists prevent_profile_role_change on public.profiles;
create trigger prevent_profile_role_change before update on public.profiles for each row execute function public.prevent_profile_privilege_escalation();

-- Balans aktyèl = depo admin konfime mwens retrè ki deja peye.
create or replace view public.plan_balances with (security_barrier = true) as
select p.id as plan_id, p.user_id, p.kanesa_id, p.title, p.goal_amount, p.has_goal, p.status,
  coalesce((select sum(d.amount) from public.deposits d where d.plan_id=p.id),0)::numeric(14,2) as deposited_total,
  coalesce((select sum(w.gross_amount) from public.withdrawal_requests w where w.plan_id=p.id and w.status='paid'),0)::numeric(14,2) as withdrawn_total,
  (coalesce((select sum(d.amount) from public.deposits d where d.plan_id=p.id),0) - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w where w.plan_id=p.id and w.status='paid'),0))::numeric(14,2) as balance,
  (coalesce((select sum(d.amount) from public.deposits d where d.plan_id=p.id),0) - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w where w.plan_id=p.id and w.status in ('pending','approved','paid')),0))::numeric(14,2) as available_balance
from public.savings_plans p
where p.user_id = auth.uid() or p.kanesa_id = auth.uid() or public.is_admin();

-- RPC: kliyan mande retrè. Montan/frè/balans kalkile sou sèvè a, pa nan navigatè a.
create or replace function public.request_withdrawal(
  p_plan_id uuid, p_gross_amount numeric, p_kind text,
  p_reason_category text default null, p_reason_text text default null,
  p_payment_method text default null
) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := auth.uid(); v_plan public.savings_plans%rowtype; v_balance numeric(14,2); v_fee_percent numeric(5,2); v_fee numeric(14,2); v_id uuid;
begin
  if v_user is null then raise exception 'Ou dwe konekte.'; end if;
  if p_gross_amount is null or p_gross_amount <= 0 then raise exception 'Montan retrè a pa valid.'; end if;
  if p_payment_method not in ('moncash','natcash','cash','bank') or p_payment_method is null then raise exception 'Metòd peman an pa valid.'; end if;
  if p_kind not in ('normal','emergency') then raise exception 'Kalite retrè a pa valid.'; end if;
  if p_kind='emergency' and p_reason_category not in ('medical','death','family_emergency','other') then raise exception 'Chwazi rezon ijans lan.'; end if;
  select * into v_plan from public.savings_plans where id=p_plan_id and user_id=v_user and status='active' for update;
  if not found then raise exception 'Plan sa a pa disponib.'; end if;
  select (coalesce((select sum(d.amount) from public.deposits d where d.plan_id=p_plan_id),0) - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w where w.plan_id=p_plan_id and w.status in ('pending','approved','paid')),0))
    into v_balance;
  if p_gross_amount > v_balance then raise exception 'Balans disponib ou pa ase.'; end if;
  select case when fees_enabled then case when p_kind='emergency' then emergency_withdrawal_fee_percent else normal_withdrawal_fee_percent end else 0 end
    into v_fee_percent from public.app_settings where id=1;
  v_fee := round(p_gross_amount * coalesce(v_fee_percent,0) / 100,2);
  insert into public.withdrawal_requests(plan_id,user_id,kind,reason_category,reason_text,gross_amount,fee_percent,fee_amount,net_amount,payment_method)
  values(p_plan_id,v_user,p_kind,p_reason_category,left(nullif(trim(p_reason_text),''),500),round(p_gross_amount,2),coalesce(v_fee_percent,0),v_fee,round(p_gross_amount-v_fee,2),p_payment_method)
  returning id into v_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(v_user,'withdrawal_requested','withdrawal_request',v_id::text,jsonb_build_object('kind',p_kind,'amount',p_gross_amount));
  return v_id;
end; $$;

-- RPC admin: konfime depo. Yon demann pa ka poste de fwa (UNIQUE deposit_request_id).
create or replace function public.admin_confirm_deposit(p_request_id uuid, p_verified_reference text default null)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_req public.deposit_requests%rowtype; v_deposit_id uuid;
begin
  if not public.is_admin() then raise exception 'Aksè admin obligatwa.'; end if;
  select * into v_req from public.deposit_requests where id=p_request_id for update;
  if not found then raise exception 'Demann depo a pa egziste.'; end if;
  if v_req.status <> 'pending' then raise exception 'Demann sa a deja trete.'; end if;
  if v_req.method in ('moncash','natcash','bank') and nullif(trim(p_verified_reference),'') is null then raise exception 'Referans ofisyèl tranzaksyon an obligatwa pou metòd sa a.'; end if;
  insert into public.deposits(plan_id,user_id,deposit_request_id,amount,method,verified_reference,confirmed_by)
  values(v_req.plan_id,v_req.user_id,v_req.id,v_req.amount,v_req.method,left(nullif(trim(p_verified_reference),''),120),auth.uid()) returning id into v_deposit_id;
  update public.deposit_requests set status='confirmed',reviewed_by=auth.uid(),reviewed_at=now() where id=p_request_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'deposit_confirmed','deposit',v_deposit_id::text,jsonb_build_object('request_id',p_request_id,'amount',v_req.amount));
  return v_deposit_id;
end; $$;

create or replace function public.admin_reject_deposit(p_request_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_req public.deposit_requests%rowtype;
begin
  if not public.is_admin() then raise exception 'Aksè admin obligatwa.'; end if;
  select * into v_req from public.deposit_requests where id=p_request_id for update;
  if not found or v_req.status <> 'pending' then raise exception 'Demann lan pa disponib.'; end if;
  update public.deposit_requests set status='rejected',admin_note=left(nullif(trim(p_note),''),500),reviewed_by=auth.uid(),reviewed_at=now() where id=p_request_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'deposit_rejected','deposit_request',p_request_id::text,jsonb_build_object('note',left(p_note,200)));
end; $$;

create or replace function public.admin_review_withdrawal(p_request_id uuid, p_decision text, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_req public.withdrawal_requests%rowtype; v_balance numeric(14,2);
begin
  if not public.is_admin() then raise exception 'Aksè admin obligatwa.'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Desizyon an pa valab.'; end if;
  select * into v_req from public.withdrawal_requests where id=p_request_id for update;
  if not found or v_req.status <> 'pending' then raise exception 'Demann retrè a pa disponib.'; end if;
  perform 1 from public.savings_plans where id=v_req.plan_id for update;
  if p_decision='approved' then
    select (coalesce((select sum(d.amount) from public.deposits d where d.plan_id=v_req.plan_id),0) - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w where w.plan_id=v_req.plan_id and w.status in ('approved','paid')),0)) into v_balance;
    if v_req.gross_amount > v_balance then raise exception 'Balans la pa ase pou apwouve demann sa a.'; end if;
  end if;
  update public.withdrawal_requests set status=p_decision::public.withdrawal_status,admin_note=left(nullif(trim(p_note),''),500),reviewed_by=auth.uid(),reviewed_at=now() where id=p_request_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'withdrawal_'||p_decision,'withdrawal_request',p_request_id::text,jsonb_build_object('note',left(p_note,200)));
end; $$;

create or replace function public.admin_mark_withdrawal_paid(p_request_id uuid, p_payment_reference text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_req public.withdrawal_requests%rowtype;
begin
  if not public.is_admin() then raise exception 'Aksè admin obligatwa.'; end if;
  if nullif(trim(p_payment_reference),'') is null then raise exception 'Mete referans peman an.'; end if;
  select * into v_req from public.withdrawal_requests where id=p_request_id for update;
  if not found or v_req.status <> 'approved' then raise exception 'Se sèlman demann apwouve ki ka make kòm peye.'; end if;
  update public.withdrawal_requests set status='paid',payment_reference=left(trim(p_payment_reference),120),paid_by=auth.uid(),paid_at=now() where id=p_request_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'withdrawal_paid','withdrawal_request',p_request_id::text,jsonb_build_object('payment_reference',left(p_payment_reference,120),'net_amount',v_req.net_amount));
end; $$;

-- RLS
alter table public.profiles enable row level security;
alter table public.app_settings enable row level security;
alter table public.savings_plans enable row level security;
alter table public.deposit_requests enable row level security;
alter table public.deposits enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.push_tokens enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_read_self_admin_kanesa_assigned on public.profiles for select using (
  id=auth.uid() or public.is_admin() or exists(select 1 from public.savings_plans sp where sp.user_id=profiles.id and sp.kanesa_id=auth.uid())
);
create policy profiles_update_self on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy settings_read_signed_in on public.app_settings for select using(auth.uid() is not null);
create policy settings_admin_update on public.app_settings for update using(public.is_admin()) with check(public.is_admin());

create policy plans_read_related on public.savings_plans for select using(user_id=auth.uid() or kanesa_id=auth.uid() or public.is_admin());
create policy plans_insert_self on public.savings_plans for insert with check(user_id=auth.uid() and kanesa_id is null);
create policy plans_update_self on public.savings_plans for update using(user_id=auth.uid()) with check(user_id=auth.uid() and kanesa_id is null);

create policy deposit_requests_read_related on public.deposit_requests for select using(user_id=auth.uid() or public.is_admin());
create policy deposit_requests_insert_self on public.deposit_requests for insert with check(user_id=auth.uid() and exists(select 1 from public.savings_plans sp where sp.id=plan_id and sp.user_id=auth.uid() and sp.status='active'));
create policy deposits_read_related on public.deposits for select using(user_id=auth.uid() or public.is_admin());

create policy withdrawals_read_related on public.withdrawal_requests for select using(user_id=auth.uid() or public.is_admin());
-- INSERT/UPDATE yo fèt sèlman atravè request_withdrawal ak fonksyon admin yo.
create policy push_tokens_owner_all on public.push_tokens for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy audit_logs_admin_read on public.audit_logs for select using(public.is_admin());

revoke all on public.plan_balances from anon;
grant select on public.plan_balances to authenticated;
revoke all on function public.current_role() from public;
revoke all on function public.is_admin() from public;
grant execute on function public.current_role() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- Pa bay itilizatè nòmal dwa chanje estati peman yo dirèkteman.
revoke insert, update, delete on public.deposits from anon, authenticated;
revoke update, delete on public.deposit_requests from anon, authenticated;
revoke insert, update, delete on public.withdrawal_requests from anon, authenticated;
revoke insert, update, delete on public.audit_logs from anon, authenticated;
revoke all on function public.admin_confirm_deposit(uuid,text) from public;
revoke all on function public.admin_reject_deposit(uuid,text) from public;
revoke all on function public.admin_review_withdrawal(uuid,text,text) from public;
revoke all on function public.admin_mark_withdrawal_paid(uuid,text) from public;
revoke all on function public.request_withdrawal(uuid,numeric,text,text,text,text) from public;
grant execute on function public.admin_confirm_deposit(uuid,text) to authenticated;
grant execute on function public.admin_reject_deposit(uuid,text) to authenticated;
grant execute on function public.admin_review_withdrawal(uuid,text,text) to authenticated;
grant execute on function public.admin_mark_withdrawal_paid(uuid,text) to authenticated;
grant execute on function public.request_withdrawal(uuid,numeric,text,text,text,text) to authenticated;

-- Premye admin: apre li fin kreye kont, verifye UUID li epi kouri:
-- update public.profiles set role='admin' where id='UUID_VERIFYE_A_LA';
-- Asire kont sa a se yon moun ou fè konfyans; pa mete SQL sa a nan yon paj piblik.


-- ===== END 0001_kane_sa_core.sql =====


-- ===== BEGIN 0002_kane_sa_control.sql =====

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


-- ===== END 0002_kane_sa_control.sql =====


-- ===== BEGIN 0003_kane_sa_admin_ops.sql =====

-- KANÈ SA 0003: operasyon admin (wòl, Kanèsa) ak rate limiting. Egzekite apre 0001 ak 0002.
create table if not exists public.rate_limits (key text primary key, window_start timestamptz not null, hits int not null);
alter table public.rate_limits enable row level security; -- pa gen politik: sèlman fonksyon ki sekirize a ka manyen l

create or replace function public.rate_limit_hit(p_key text, p_max int, p_window_seconds int)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare r public.rate_limits;
begin
  if auth.uid() is null then return false; end if;
  insert into public.rate_limits(key, window_start, hits) values (auth.uid()::text || ':' || p_key, now(), 1)
  on conflict (key) do update set
    hits = case when public.rate_limits.window_start < now() - make_interval(secs => p_window_seconds) then 1 else public.rate_limits.hits + 1 end,
    window_start = case when public.rate_limits.window_start < now() - make_interval(secs => p_window_seconds) then now() else public.rate_limits.window_start end
  returning * into r;
  return r.hits <= p_max;
end $$;

create or replace function public.admin_set_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_role not in ('kliyan','kanesa','admin') then raise exception 'Wòl la pa valid.'; end if;
  if p_user_id = auth.uid() then raise exception 'Ou pa ka chanje pwòp wòl ou.'; end if;
  update public.profiles set role = p_role::public.app_role where id = p_user_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'role_changed', 'profile', p_user_id, jsonb_build_object('role', p_role));
end $$;

create or replace function public.admin_assign_kanesa(p_plan_id uuid, p_kanesa_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_kanesa_id is not null and not exists (select 1 from public.profiles where id = p_kanesa_id and role = 'kanesa') then
    raise exception 'Itilizatè a pa gen wòl Kanèsa.';
  end if;
  update public.savings_plans set kanesa_id = p_kanesa_id where id = p_plan_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'kanesa_assigned', 'savings_plan', p_plan_id, jsonb_build_object('kanesa_id', p_kanesa_id));
end $$;

revoke all on function public.rate_limit_hit(text,int,int), public.admin_set_role(uuid,text), public.admin_assign_kanesa(uuid,uuid) from public, anon;
grant execute on function public.rate_limit_hit(text,int,int), public.admin_set_role(uuid,text), public.admin_assign_kanesa(uuid,uuid) to authenticated;


-- ===== END 0003_kane_sa_admin_ops.sql =====


-- ===== BEGIN 0004_kane_sa_ledger_compliance.sql =====

-- KANÈ SA 0004: ledger doub-antre (append-only), KYC/AML, pòtay lansman. Egzekite apre 0003.
create table if not exists public.ledger_entries (
  id bigint generated always as identity primary key,
  txn_id uuid not null,
  account text not null check (account in ('platform_cash','customer_liability','fee_revenue')),
  plan_id uuid references public.savings_plans(id),
  debit numeric(14,2) not null default 0 check (debit >= 0),
  credit numeric(14,2) not null default 0 check (credit >= 0),
  ref_type text not null check (ref_type in ('deposit','withdrawal')),
  ref_id uuid not null,
  created_at timestamptz not null default now(),
  check ((debit > 0) <> (credit > 0)),
  unique (ref_type, ref_id, account)
);
create index if not exists ledger_txn_idx on public.ledger_entries (txn_id);
create index if not exists ledger_plan_idx on public.ledger_entries (plan_id, account);

create or replace function public.ledger_block_change() returns trigger language plpgsql as $$
begin raise exception 'Ledger la se append-only: pa gen modifikasyon ni efasman.'; end $$;
drop trigger if exists ledger_no_update on public.ledger_entries;
create trigger ledger_no_update before update or delete on public.ledger_entries for each row execute function public.ledger_block_change();

create or replace function public.ledger_check_balanced() returns trigger language plpgsql as $$
begin
  if (select coalesce(sum(debit) - sum(credit), 0) from public.ledger_entries where txn_id = new.txn_id) <> 0 then
    raise exception 'Tranzaksyon ledger pa balanse (txn %).', new.txn_id;
  end if;
  return null;
end $$;
create constraint trigger ledger_balanced after insert on public.ledger_entries deferrable initially deferred for each row execute function public.ledger_check_balanced();

create or replace function public.post_deposit_ledger() returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare t uuid := gen_random_uuid();
begin
  insert into public.ledger_entries(txn_id, account, plan_id, debit, credit, ref_type, ref_id) values
    (t, 'platform_cash', new.plan_id, new.amount, 0, 'deposit', new.id),
    (t, 'customer_liability', new.plan_id, 0, new.amount, 'deposit', new.id);
  return new;
end $$;
drop trigger if exists deposits_post_ledger on public.deposits;
create trigger deposits_post_ledger after insert on public.deposits for each row execute function public.post_deposit_ledger();

create or replace function public.post_withdrawal_ledger() returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare t uuid := gen_random_uuid();
begin
  insert into public.ledger_entries(txn_id, account, plan_id, debit, credit, ref_type, ref_id) values
    (t, 'customer_liability', new.plan_id, new.gross_amount, 0, 'withdrawal', new.id),
    (t, 'platform_cash', new.plan_id, 0, new.net_amount, 'withdrawal', new.id);
  if new.fee_amount > 0 then
    insert into public.ledger_entries(txn_id, account, plan_id, debit, credit, ref_type, ref_id)
    values (t, 'fee_revenue', new.plan_id, 0, new.fee_amount, 'withdrawal', new.id);
  end if;
  return new;
end $$;
drop trigger if exists withdrawals_post_ledger on public.withdrawal_requests;
create trigger withdrawals_post_ledger after update on public.withdrawal_requests for each row
  when (old.status is distinct from 'paid' and new.status = 'paid') execute function public.post_withdrawal_ledger();

-- Backfill done ki deja egziste.
create or replace function public.post_deposit_ledger_manual(p_id uuid) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare d public.deposits; t uuid := gen_random_uuid();
begin
  select * into d from public.deposits where id = p_id;
  insert into public.ledger_entries(txn_id, account, plan_id, debit, credit, ref_type, ref_id) values
    (t, 'platform_cash', d.plan_id, d.amount, 0, 'deposit', d.id), (t, 'customer_liability', d.plan_id, 0, d.amount, 'deposit', d.id);
end $$;
do $$ declare r record; w public.withdrawal_requests; t uuid; begin
  for r in select id from public.deposits d where not exists (select 1 from public.ledger_entries l where l.ref_type='deposit' and l.ref_id=d.id) loop
    perform public.post_deposit_ledger_manual(r.id);
  end loop;
  for w in select * from public.withdrawal_requests x where x.status='paid' and not exists (select 1 from public.ledger_entries l where l.ref_type='withdrawal' and l.ref_id=x.id) loop
    t := gen_random_uuid();
    insert into public.ledger_entries(txn_id, account, plan_id, debit, credit, ref_type, ref_id) values
      (t, 'customer_liability', w.plan_id, w.gross_amount, 0, 'withdrawal', w.id), (t, 'platform_cash', w.plan_id, 0, w.net_amount, 'withdrawal', w.id);
    if w.fee_amount > 0 then insert into public.ledger_entries(txn_id, account, plan_id, debit, credit, ref_type, ref_id) values (t, 'fee_revenue', w.plan_id, 0, w.fee_amount, 'withdrawal', w.id); end if;
  end loop;
end $$;

alter table public.ledger_entries enable row level security;
create policy ledger_admin_read on public.ledger_entries for select to authenticated using (public.is_admin());
revoke all on public.ledger_entries from anon; grant select on public.ledger_entries to authenticated;

-- Konfòmite
create table if not exists public.compliance_settings (
  id int primary key default 1 check (id = 1),
  kyc_threshold numeric(14,2) not null default 25000,
  aml_review_amount numeric(14,2) not null default 100000,
  aml_max_requests_24h int not null default 8,
  live_mode boolean not null default false
);
insert into public.compliance_settings(id) values (1) on conflict do nothing;

create table if not exists public.kyc_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  legal_name text not null check (char_length(legal_name) between 3 and 120),
  date_of_birth date not null,
  address text not null check (char_length(address) between 5 and 240),
  document_type text not null check (document_type in ('cin','passport','nif','permis')),
  document_last4 text not null check (document_last4 ~ '^[A-Za-z0-9]{4}$'),
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  review_note text, reviewed_by uuid, reviewed_at timestamptz,
  submitted_at timestamptz not null default now()
);
create table if not exists public.aml_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  ref_type text not null, ref_id uuid not null, reason text not null,
  status text not null default 'open' check (status in ('open','cleared')),
  created_at timestamptz not null default now(), reviewed_by uuid, reviewed_at timestamptz
);
create table if not exists public.go_live_gates (
  key text primary key, label text not null, done boolean not null default false, done_by uuid, done_at timestamptz
);
insert into public.go_live_gates(key, label) values
  ('legal_entity','Antite legal anrejistre'),('brh_authorization','Otorizasyon/konfòmite BRH konfime pa avoka'),
  ('terms_privacy','Kondisyon ak vi prive revize pa avoka'),('kyc_procedure','Pwosedi KYC dokimante'),
  ('aml_officer','Responsab AML/konfòmite nonmen'),('segregated_funds','Kont bank/fon kliyan separe'),
  ('backups_dr','Backup ak plan rekiperasyon teste'),('security_audit','Odit sekirite fèt'),('support_process','Pwosesis sipò ak plent defini')
on conflict do nothing;

alter table public.compliance_settings enable row level security;
alter table public.kyc_profiles enable row level security;
alter table public.aml_flags enable row level security;
alter table public.go_live_gates enable row level security;
create policy kyc_read on public.kyc_profiles for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy aml_read on public.aml_flags for select to authenticated using (public.is_admin());
create policy gates_read on public.go_live_gates for select to authenticated using (public.is_admin());
create policy comp_read on public.compliance_settings for select to authenticated using (public.is_admin());
revoke all on public.compliance_settings, public.kyc_profiles, public.aml_flags, public.go_live_gates from anon;
grant select on public.compliance_settings, public.kyc_profiles, public.aml_flags, public.go_live_gates to authenticated;

create or replace function public.submit_kyc(p_legal_name text, p_dob date, p_address text, p_doc_type text, p_doc_last4 text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Ou dwe konekte.'; end if;
  if p_dob > current_date - interval '18 years' then raise exception 'Ou dwe gen omwen 18 an.'; end if;
  insert into public.kyc_profiles(user_id, legal_name, date_of_birth, address, document_type, document_last4)
  values (auth.uid(), trim(p_legal_name), p_dob, trim(p_address), p_doc_type, upper(p_doc_last4))
  on conflict (user_id) do update set legal_name = excluded.legal_name, date_of_birth = excluded.date_of_birth, address = excluded.address,
    document_type = excluded.document_type, document_last4 = excluded.document_last4, status = 'pending', review_note = null, reviewed_by = null, reviewed_at = null, submitted_at = now()
  where public.kyc_profiles.status <> 'verified';
end $$;

create or replace function public.admin_review_kyc(p_user_id uuid, p_decision text, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_decision not in ('verified','rejected') then raise exception 'Desizyon pa valid.'; end if;
  update public.kyc_profiles set status = p_decision, review_note = p_note, reviewed_by = auth.uid(), reviewed_at = now() where user_id = p_user_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata) values (auth.uid(), 'kyc_' || p_decision, 'kyc', p_user_id, '{}'::jsonb);
end $$;

create or replace function public.admin_clear_aml_flag(p_id uuid) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  update public.aml_flags set status = 'cleared', reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata) values (auth.uid(), 'aml_cleared', 'aml_flag', p_id, '{}'::jsonb);
end $$;

create or replace function public.admin_set_gate(p_key text, p_done boolean) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  update public.go_live_gates set done = p_done, done_by = case when p_done then auth.uid() end, done_at = case when p_done then now() end where key = p_key;
  if not p_done then update public.compliance_settings set live_mode = false where id = 1; end if;
end $$;

create or replace function public.admin_set_live_mode(p_live boolean) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_live and exists (select 1 from public.go_live_gates where not done) then raise exception 'Tout pòtay lansman yo dwe fini anvan mòd reyèl la.'; end if;
  update public.compliance_settings set live_mode = p_live where id = 1;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata) values (auth.uid(), 'live_mode_set', 'settings', null, jsonb_build_object('live', p_live));
end $$;

create or replace function public.enforce_kyc_for_withdrawal() returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare lim numeric;
begin
  select kyc_threshold into lim from public.compliance_settings where id = 1;
  if new.gross_amount > lim and not exists (select 1 from public.kyc_profiles where user_id = new.user_id and status = 'verified') then
    raise exception 'KYC obligatwa pou retrè ki depase % HTG.', lim;
  end if;
  return new;
end $$;
drop trigger if exists withdrawal_kyc_gate on public.withdrawal_requests;
create trigger withdrawal_kyc_gate before insert on public.withdrawal_requests for each row execute function public.enforce_kyc_for_withdrawal();

create or replace function public.aml_screen() returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare amt numeric := coalesce((to_jsonb(new)->>'amount')::numeric, (to_jsonb(new)->>'gross_amount')::numeric); s public.compliance_settings; n int;
begin
  select * into s from public.compliance_settings where id = 1;
  if amt >= s.aml_review_amount then
    insert into public.aml_flags(user_id, ref_type, ref_id, reason) values (new.user_id, tg_table_name, new.id, 'large_amount');
  end if;
  select (select count(*) from public.deposit_requests where user_id = new.user_id and created_at > now() - interval '24 hours')
       + (select count(*) from public.withdrawal_requests where user_id = new.user_id and created_at > now() - interval '24 hours') into n;
  if n > s.aml_max_requests_24h then
    insert into public.aml_flags(user_id, ref_type, ref_id, reason) values (new.user_id, tg_table_name, new.id, 'high_velocity');
  end if;
  return new;
end $$;
drop trigger if exists aml_deposit_screen on public.deposit_requests;
create trigger aml_deposit_screen after insert on public.deposit_requests for each row execute function public.aml_screen();
drop trigger if exists aml_withdrawal_screen on public.withdrawal_requests;
create trigger aml_withdrawal_screen after insert on public.withdrawal_requests for each row execute function public.aml_screen();

revoke all on function public.submit_kyc(text,date,text,text,text), public.admin_review_kyc(uuid,text,text), public.admin_clear_aml_flag(uuid), public.admin_set_gate(text,boolean), public.admin_set_live_mode(boolean) from public, anon;
grant execute on function public.submit_kyc(text,date,text,text,text), public.admin_review_kyc(uuid,text,text), public.admin_clear_aml_flag(uuid), public.admin_set_gate(text,boolean), public.admin_set_live_mode(boolean) to authenticated;

-- Kontwòl entegrite ogmante ak ledger.
create or replace view public.integrity_checks with (security_barrier = true) as
select c.* from (
  select 'negative_balance'::text as check_name, count(*)::int as violations from public.plan_balances where balance < 0
  union all select 'over_reserved', count(*)::int from public.plan_balances where available_balance < 0
  union all select 'duplicate_references', count(*)::int from (select verified_reference from public.deposits where verified_reference is not null group by 1 having count(*) > 1) d
  union all select 'ledger_unbalanced', count(*)::int from (select txn_id from public.ledger_entries group by txn_id having sum(debit) <> sum(credit)) u
  union all select 'ledger_vs_balance_mismatch', count(*)::int from public.plan_balances b
    where b.balance <> coalesce((select sum(credit - debit) from public.ledger_entries l where l.plan_id = b.plan_id and l.account = 'customer_liability'), 0)
) c where public.is_admin();


-- ===== END 0004_kane_sa_ledger_compliance.sql =====


-- ===== BEGIN 0005_kane_sa_automatic_withdrawals.sql =====

-- KANÈ SA 0005: règles de retrait transparentes et autorisation automatique.
-- À exécuter après 0004_kane_sa_ledger_compliance.sql.
-- IMPORTANT: l'autorisation interne n'est PAS un paiement externe automatique.

alter table public.withdrawal_requests
  add column if not exists authorization_mode text not null default 'legacy_manual',
  add column if not exists manual_review_reason text,
  add column if not exists auto_authorized_at timestamptz,
  add column if not exists idempotency_key uuid;

do $$ begin
  alter table public.withdrawal_requests
    add constraint withdrawal_authorization_mode_check
    check (authorization_mode in ('automatic','manual_review','legacy_manual'));
exception when duplicate_object then null; end $$;

create unique index if not exists withdrawal_user_idempotency_uq
  on public.withdrawal_requests(user_id, idempotency_key)
  where idempotency_key is not null;

-- Simulation du devis côté serveur. Le navigateur ne choisit jamais le taux de frais.
create or replace function public.quote_withdrawal(p_plan_id uuid, p_gross_amount numeric)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_plan public.savings_plans%rowtype;
  v_available numeric(14,2);
  v_kind text;
  v_fee_percent numeric(5,2) := 0;
  v_fee numeric(14,2);
  v_net numeric(14,2);
  v_fees_enabled boolean := false;
  v_aml public.compliance_settings%rowtype;
  v_request_count integer := 0;
  v_review_reason text;
  v_manual_review boolean := false;
  v_kyc_required boolean := false;
begin
  if v_user is null then raise exception 'Ou dwe konekte.'; end if;
  if p_gross_amount is null or p_gross_amount <= 0 or p_gross_amount > 10000000 then
    raise exception 'Montan retrè a pa valid.';
  end if;
  select * into v_plan
  from public.savings_plans
  where id = p_plan_id and user_id = v_user and status = 'active';
  if not found then raise exception 'Plan sa a pa disponib.'; end if;

  select (
    coalesce((select sum(d.amount) from public.deposits d where d.plan_id = p_plan_id), 0)
    - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w
      where w.plan_id = p_plan_id and w.status in ('pending','approved','paid')), 0)
  )::numeric(14,2) into v_available;
  if round(p_gross_amount, 2) > v_available then raise exception 'Balans disponib ou pa ase.'; end if;

  -- Plan san objektif: frè nòmal. Plan objektif ki poko rive nan objektif li:
  -- retrè a klase ijans otomatikman. Lè objektif la deja rive, frè nòmal aplike.
  if v_plan.has_goal and v_available < v_plan.goal_amount then
    v_kind := 'emergency';
  else
    v_kind := 'normal';
  end if;

  select fees_enabled,
         case when v_kind = 'emergency' then emergency_withdrawal_fee_percent else normal_withdrawal_fee_percent end
    into v_fees_enabled, v_fee_percent
  from public.app_settings where id = 1;
  if not coalesce(v_fees_enabled, false) then v_fee_percent := 0; end if;
  v_fee := round(round(p_gross_amount, 2) * coalesce(v_fee_percent, 0) / 100, 2);
  v_net := round(round(p_gross_amount, 2) - v_fee, 2);

  select * into v_aml from public.compliance_settings where id = 1;
  if found then
    v_kyc_required := p_gross_amount > v_aml.kyc_threshold
      and not exists (select 1 from public.kyc_profiles k where k.user_id = v_user and k.status = 'verified');

    select
      (select count(*) from public.deposit_requests d where d.user_id = v_user and d.created_at >= now() - interval '24 hours')
      + (select count(*) from public.withdrawal_requests w where w.user_id = v_user and w.created_at >= now() - interval '24 hours')
    into v_request_count;

    if p_gross_amount >= v_aml.aml_review_amount then
      v_manual_review := true;
      v_review_reason := 'large_amount';
    end if;
    if v_request_count + 1 > v_aml.aml_max_requests_24h then
      v_manual_review := true;
      v_review_reason := concat_ws(',', v_review_reason, 'high_velocity');
    end if;
  end if;

  return jsonb_build_object(
    'plan_id', p_plan_id,
    'available_balance', v_available,
    'has_goal', v_plan.has_goal,
    'goal_amount', v_plan.goal_amount,
    'goal_reached', (not v_plan.has_goal or v_available >= v_plan.goal_amount),
    'kind', v_kind,
    'fee_percent', coalesce(v_fee_percent, 0),
    'fee_amount', v_fee,
    'gross_amount', round(p_gross_amount, 2),
    'net_amount', v_net,
    'fees_enabled', coalesce(v_fees_enabled, false),
    'reason_required', (v_kind = 'emergency'),
    'manual_review', v_manual_review,
    'manual_review_reason', v_review_reason,
    'kyc_required', v_kyc_required
  );
end;
$$;

-- Retire ansyen RPC la pou pa kite ansyen règ "tout retrè bezwen admin" aktif.
drop function if exists public.request_withdrawal(uuid, numeric, text, text, text, text);

create or replace function public.request_withdrawal(
  p_plan_id uuid,
  p_gross_amount numeric,
  p_kind text,
  p_reason_category text default null,
  p_reason_text text default null,
  p_payment_method text default null,
  p_expected_fee_percent numeric default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_plan public.savings_plans%rowtype;
  v_existing public.withdrawal_requests%rowtype;
  v_quote jsonb;
  v_kind text;
  v_fee_percent numeric(5,2);
  v_fee numeric(14,2);
  v_net numeric(14,2);
  v_status public.withdrawal_status;
  v_mode text;
  v_review_reason text;
  v_id uuid;
begin
  if v_user is null then raise exception 'Ou dwe konekte.'; end if;
  if p_idempotency_key is null then raise exception 'Kle sekirite demann lan obligatwa. Rekòmanse demann lan.'; end if;
  if p_payment_method not in ('moncash','natcash','cash','bank') or p_payment_method is null then
    raise exception 'Metòd peman an pa valid.';
  end if;

  -- Retry sou menm idempotency key la retounen menm rezilta a, san nouvo retrè.
  select * into v_existing from public.withdrawal_requests
  where user_id = v_user and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.plan_id <> p_plan_id
       or v_existing.gross_amount <> round(p_gross_amount, 2)
       or v_existing.payment_method <> p_payment_method
       or v_existing.kind <> p_kind
       or v_existing.fee_percent <> round(coalesce(p_expected_fee_percent, -1), 2)
       or v_existing.reason_category is distinct from p_reason_category
       or v_existing.reason_text is distinct from case when p_kind = 'emergency' then left(nullif(trim(p_reason_text), ''), 500) else null end then
      raise exception 'Kle demann sa a deja itilize pou lòt done.';
    end if;
    return jsonb_build_object(
      'id', v_existing.id, 'status', v_existing.status::text,
      'kind', v_existing.kind, 'gross_amount', v_existing.gross_amount,
      'fee_percent', v_existing.fee_percent, 'fee_amount', v_existing.fee_amount,
      'net_amount', v_existing.net_amount, 'authorization_mode', v_existing.authorization_mode,
      'manual_review_reason', v_existing.manual_review_reason, 'replayed', true
    );
  end if;

  if not public.rate_limit_hit('withdrawal', 5, 300) then
    raise exception 'Twòp demann retrè. Eseye ankò nan kèk minit.';
  end if;

  -- Lock plan an pou de retrè an menm tan pa depanse menm balans lan.
  select * into v_plan from public.savings_plans
  where id = p_plan_id and user_id = v_user and status = 'active'
  for update;
  if not found then raise exception 'Plan sa a pa disponib.'; end if;

  v_quote := public.quote_withdrawal(p_plan_id, p_gross_amount);
  v_kind := v_quote->>'kind';
  v_fee_percent := (v_quote->>'fee_percent')::numeric;
  v_fee := (v_quote->>'fee_amount')::numeric;
  v_net := (v_quote->>'net_amount')::numeric;
  v_review_reason := nullif(v_quote->>'manual_review_reason', '');

  if p_kind is distinct from v_kind then
    raise exception 'Règ plan an chanje depi kalkil la. Rekalkile frè yo anvan ou konfime.';
  end if;
  if p_expected_fee_percent is null or round(p_expected_fee_percent, 2) <> round(v_fee_percent, 2) then
    raise exception 'Frè retrè a chanje. Rekalkile epi konfime ankò.';
  end if;
  if coalesce((v_quote->>'kyc_required')::boolean, false) then
    raise exception 'KYC obligatwa pou retrè sa a. Tanpri fini verifikasyon idantite a anvan ou soumèt.';
  end if;
  if v_kind = 'emergency' and (p_reason_category is null or p_reason_category not in ('medical','death','family_emergency','other')) then
    raise exception 'Chwazi rezon ijans lan.';
  end if;

  if coalesce((v_quote->>'manual_review')::boolean, false) then
    v_status := 'pending';
    v_mode := 'manual_review';
  else
    v_status := 'approved';
    v_mode := 'automatic';
  end if;

  insert into public.withdrawal_requests(
    plan_id, user_id, kind, reason_category, reason_text,
    gross_amount, fee_percent, fee_amount, net_amount, payment_method,
    status, authorization_mode, manual_review_reason, auto_authorized_at, idempotency_key
  ) values (
    p_plan_id, v_user, v_kind,
    case when v_kind = 'emergency' then p_reason_category else null end,
    case when v_kind = 'emergency' then left(nullif(trim(p_reason_text), ''), 500) else null end,
    round(p_gross_amount, 2), v_fee_percent, v_fee, v_net, p_payment_method,
    v_status, v_mode, v_review_reason,
    case when v_mode = 'automatic' then now() else null end,
    p_idempotency_key
  ) returning id into v_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (
    v_user,
    case when v_mode = 'automatic' then 'withdrawal_auto_authorized' else 'withdrawal_held_for_review' end,
    'withdrawal_request', v_id::text,
    jsonb_build_object(
      'kind', v_kind, 'gross_amount', round(p_gross_amount, 2),
      'fee_percent', v_fee_percent, 'fee_amount', v_fee, 'net_amount', v_net,
      'authorization_mode', v_mode, 'manual_review_reason', v_review_reason
    )
  );

  return jsonb_build_object(
    'id', v_id, 'status', v_status::text, 'kind', v_kind,
    'gross_amount', round(p_gross_amount, 2), 'fee_percent', v_fee_percent,
    'fee_amount', v_fee, 'net_amount', v_net,
    'authorization_mode', v_mode, 'manual_review_reason', v_review_reason,
    'replayed', false
  );
end;
$$;

-- Revizyon manyèl rezève sèlman pou demann ki te kenbe nan verifikasyon sekirite,
-- ansanm ak ansyen demann legacy ki te deja an atant anvan migration sa a.
create or replace function public.admin_review_withdrawal(p_request_id uuid, p_decision text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_req public.withdrawal_requests%rowtype;
  v_available numeric(14,2);
begin
  if not public.is_admin() then raise exception 'Aksè admin obligatwa.'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Desizyon an pa valab.'; end if;
  select * into v_req from public.withdrawal_requests where id = p_request_id for update;
  if not found or v_req.status <> 'pending' then raise exception 'Demann retrè a pa disponib.'; end if;
  if v_req.authorization_mode = 'automatic' then raise exception 'Retrè sa a deja otorize otomatikman.'; end if;

  perform 1 from public.savings_plans where id = v_req.plan_id for update;
  if p_decision = 'approved' then
    select (
      coalesce((select sum(d.amount) from public.deposits d where d.plan_id = v_req.plan_id), 0)
      - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w
        where w.plan_id = v_req.plan_id and w.id <> p_request_id and w.status in ('pending','approved','paid')), 0)
    )::numeric(14,2) into v_available;
    if v_req.gross_amount > v_available then raise exception 'Balans la pa ase pou apwouve demann sa a.'; end if;
  end if;

  update public.withdrawal_requests
  set status = p_decision::public.withdrawal_status,
      admin_note = left(nullif(trim(p_note), ''), 500),
      reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_request_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'withdrawal_' || p_decision, 'withdrawal_request', p_request_id::text,
    jsonb_build_object('note', left(p_note, 200), 'authorization_mode', v_req.authorization_mode));
end;
$$;

revoke all on function public.quote_withdrawal(uuid,numeric) from public, anon;
grant execute on function public.quote_withdrawal(uuid,numeric) to authenticated;
revoke all on function public.request_withdrawal(uuid,numeric,text,text,text,text,numeric,uuid) from public, anon;
grant execute on function public.request_withdrawal(uuid,numeric,text,text,text,text,numeric,uuid) to authenticated;

comment on column public.withdrawal_requests.authorization_mode is
  'automatic = otorizasyon san admin; manual_review = risk hold; legacy_manual = demann istorik.';
comment on column public.withdrawal_requests.auto_authorized_at is
  'Dat sistèm nan te otorize retrè a. Sa pa pwouve lajan ekstèn lan te peye.';


-- ===== END 0005_kane_sa_automatic_withdrawals.sql =====

-- ===== BEGIN 0006_kane_sa_withdrawal_hardening.sql =====
-- KANÈ SA 0006: hardening rate limiting and withdrawal goal classification.
-- Apply AFTER 0005_kane_sa_automatic_withdrawals.sql.
-- No payment-provider integration is enabled by this migration.

-- A public authenticated caller may reach this helper through PostgREST.
-- Lock the allowed keys and quotas so a caller cannot raise their own limits.
create or replace function public.rate_limit_hit(
  p_key text,
  p_max integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit public.rate_limits%rowtype;
  v_allowed_max integer;
  v_allowed_window integer;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return false;
  end if;

  case p_key
    when 'deposit' then
      v_allowed_max := 10;
      v_allowed_window := 60;
    when 'tx' then
      v_allowed_max := 30;
      v_allowed_window := 60;
    when 'withdrawal_quote' then
      v_allowed_max := 30;
      v_allowed_window := 60;
    when 'withdrawal' then
      v_allowed_max := 5;
      v_allowed_window := 300;
    else
      raise exception 'Kle limit sa a pa otorize.';
  end case;

  if p_max is distinct from v_allowed_max
     or p_window_seconds is distinct from v_allowed_window then
    raise exception 'Paramèt rate limit sa yo pa otorize.';
  end if;

  insert into public.rate_limits(key, window_start, hits)
  values (v_user_id::text || ':' || p_key, pg_catalog.now(), 1)
  on conflict (key) do update set
    hits = case
      when public.rate_limits.window_start < pg_catalog.now() - pg_catalog.make_interval(secs => p_window_seconds) then 1
      else public.rate_limits.hits + 1
    end,
    window_start = case
      when public.rate_limits.window_start < pg_catalog.now() - pg_catalog.make_interval(secs => p_window_seconds) then pg_catalog.now()
      else public.rate_limits.window_start
    end
  returning * into v_limit;

  return v_limit.hits <= v_allowed_max;
end;
$$;

revoke all on function public.rate_limit_hit(text, integer, integer) from public, anon;
grant execute on function public.rate_limit_hit(text, integer, integer) to authenticated;

-- Quote logic: the goal is considered reached from the actual current balance
-- (deposits minus PAID withdrawals), not from available balance after reserves.
-- Pending/approved withdrawals reserve funds but do not count as paid withdrawals.
create or replace function public.quote_withdrawal(
  p_plan_id uuid,
  p_gross_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_plan public.savings_plans%rowtype;
  v_balance numeric(14,2);
  v_available numeric(14,2);
  v_kind text;
  v_fee_percent numeric(5,2) := 0;
  v_fee numeric(14,2);
  v_net numeric(14,2);
  v_fees_enabled boolean := false;
  v_aml public.compliance_settings%rowtype;
  v_request_count integer := 0;
  v_review_reason text;
  v_manual_review boolean := false;
  v_kyc_required boolean := false;
begin
  if v_user is null then
    raise exception 'Ou dwe konekte.';
  end if;
  if p_gross_amount is null or round(p_gross_amount, 2) <= 0 or p_gross_amount > 10000000 then
    raise exception 'Montan retrè a pa valid.';
  end if;

  select * into v_plan
  from public.savings_plans
  where id = p_plan_id and user_id = v_user and status = 'active';
  if not found then
    raise exception 'Plan sa a pa disponib.';
  end if;

  if not public.rate_limit_hit('withdrawal_quote', 30, 60) then
    raise exception 'Twòp kalkil retrè. Eseye ankò nan yon minit.';
  end if;

  select (
    coalesce((select sum(d.amount) from public.deposits d where d.plan_id = p_plan_id), 0)
    - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w
      where w.plan_id = p_plan_id and w.status = 'paid'), 0)
  )::numeric(14,2)
  into v_balance;

  select (
    coalesce((select sum(d.amount) from public.deposits d where d.plan_id = p_plan_id), 0)
    - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w
      where w.plan_id = p_plan_id and w.status in ('pending','approved','paid')), 0)
  )::numeric(14,2)
  into v_available;

  if round(p_gross_amount, 2) > v_available then
    raise exception 'Balans disponib ou pa ase.';
  end if;

  -- Plan san objektif: frè nòmal. Plan objektif ki poko rive nan objektif li,
  -- sou baz balans reyèl ki poko peye soti: frè ijans.
  if v_plan.has_goal and v_balance < v_plan.goal_amount then
    v_kind := 'emergency';
  else
    v_kind := 'normal';
  end if;

  select s.fees_enabled,
         case when v_kind = 'emergency' then s.emergency_withdrawal_fee_percent
              else s.normal_withdrawal_fee_percent end
  into v_fees_enabled, v_fee_percent
  from public.app_settings s
  where s.id = 1;

  if not coalesce(v_fees_enabled, false) then
    v_fee_percent := 0;
  end if;
  v_fee := round(round(p_gross_amount, 2) * coalesce(v_fee_percent, 0) / 100, 2);
  v_net := round(round(p_gross_amount, 2) - v_fee, 2);

  select * into v_aml
  from public.compliance_settings
  where id = 1;

  if found then
    v_kyc_required := p_gross_amount > v_aml.kyc_threshold
      and not exists (
        select 1 from public.kyc_profiles k
        where k.user_id = v_user and k.status = 'verified'
      );

    select
      (select count(*) from public.deposit_requests d
       where d.user_id = v_user and d.created_at >= pg_catalog.now() - interval '24 hours')
      +
      (select count(*) from public.withdrawal_requests w
       where w.user_id = v_user and w.created_at >= pg_catalog.now() - interval '24 hours')
    into v_request_count;

    if p_gross_amount >= v_aml.aml_review_amount then
      v_manual_review := true;
      v_review_reason := 'large_amount';
    end if;
    if v_request_count + 1 > v_aml.aml_max_requests_24h then
      v_manual_review := true;
      v_review_reason := pg_catalog.concat_ws(',', v_review_reason, 'high_velocity');
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'plan_id', p_plan_id,
    'balance', v_balance,
    'available_balance', v_available,
    'has_goal', v_plan.has_goal,
    'goal_amount', v_plan.goal_amount,
    'goal_reached', (not v_plan.has_goal or v_balance >= v_plan.goal_amount),
    'kind', v_kind,
    'fee_percent', coalesce(v_fee_percent, 0),
    'fee_amount', v_fee,
    'gross_amount', round(p_gross_amount, 2),
    'net_amount', v_net,
    'fees_enabled', coalesce(v_fees_enabled, false),
    'reason_required', (v_kind = 'emergency'),
    'manual_review', v_manual_review,
    'manual_review_reason', v_review_reason,
    'kyc_required', v_kyc_required
  );
end;
$$;

revoke all on function public.quote_withdrawal(uuid, numeric) from public, anon;
grant execute on function public.quote_withdrawal(uuid, numeric) to authenticated;

-- Recreate the request function with a fixed search_path and explicit role grants.
-- The business logic and idempotency contract remain the same as migration 0005.
create or replace function public.request_withdrawal(
  p_plan_id uuid,
  p_gross_amount numeric,
  p_kind text,
  p_reason_category text default null,
  p_reason_text text default null,
  p_payment_method text default null,
  p_expected_fee_percent numeric default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_plan public.savings_plans%rowtype;
  v_existing public.withdrawal_requests%rowtype;
  v_quote jsonb;
  v_kind text;
  v_fee_percent numeric(5,2);
  v_fee numeric(14,2);
  v_net numeric(14,2);
  v_status public.withdrawal_status;
  v_mode text;
  v_review_reason text;
  v_id uuid;
begin
  if v_user is null then
    raise exception 'Ou dwe konekte.';
  end if;
  if p_idempotency_key is null then
    raise exception 'Kle sekirite demann lan obligatwa. Rekòmanse demann lan.';
  end if;
  if p_gross_amount is null or round(p_gross_amount, 2) <= 0 or p_gross_amount > 10000000 then
    raise exception 'Montan retrè a pa valid.';
  end if;
  if p_kind is null or p_kind not in ('normal','emergency') then
    raise exception 'Kalite retrè a pa valid.';
  end if;
  if p_payment_method is null or p_payment_method not in ('moncash','natcash','cash','bank') then
    raise exception 'Metòd peman an pa valid.';
  end if;

  -- Serialize retries by user + idempotency key, even if a malicious retry
  -- changes the plan_id. The transaction-level advisory lock is released
  -- automatically when this RPC transaction ends.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user::text || ':' || p_idempotency_key::text, 0)
  );

  select * into v_existing
  from public.withdrawal_requests
  where user_id = v_user and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.plan_id <> p_plan_id
       or v_existing.gross_amount <> round(p_gross_amount, 2)
       or v_existing.payment_method <> p_payment_method
       or v_existing.kind <> p_kind
       or v_existing.fee_percent <> round(coalesce(p_expected_fee_percent, -1), 2)
       or v_existing.reason_category is distinct from case when p_kind = 'emergency' then p_reason_category else null end
       or v_existing.reason_text is distinct from case
            when p_kind = 'emergency' then left(nullif(pg_catalog.btrim(p_reason_text), ''), 500)
            else null
          end then
      raise exception 'Kle demann sa a deja itilize pou lòt done.';
    end if;

    return pg_catalog.jsonb_build_object(
      'id', v_existing.id,
      'status', v_existing.status::text,
      'kind', v_existing.kind,
      'gross_amount', v_existing.gross_amount,
      'fee_percent', v_existing.fee_percent,
      'fee_amount', v_existing.fee_amount,
      'net_amount', v_existing.net_amount,
      'authorization_mode', v_existing.authorization_mode,
      'manual_review_reason', v_existing.manual_review_reason,
      'replayed', true
    );
  end if;

  select * into v_plan
  from public.savings_plans
  where id = p_plan_id and user_id = v_user and status = 'active'
  for update;
  if not found then
    raise exception 'Plan sa a pa disponib.';
  end if;

  -- A second idempotency lookup after locking the plan closes the race where
  -- two concurrent retries both passed the first lookup before either insert.
  select * into v_existing
  from public.withdrawal_requests
  where user_id = v_user and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.plan_id <> p_plan_id
       or v_existing.gross_amount <> round(p_gross_amount, 2)
       or v_existing.payment_method <> p_payment_method
       or v_existing.kind <> p_kind
       or v_existing.fee_percent <> round(coalesce(p_expected_fee_percent, -1), 2)
       or v_existing.reason_category is distinct from case when p_kind = 'emergency' then p_reason_category else null end
       or v_existing.reason_text is distinct from case
            when p_kind = 'emergency' then left(nullif(pg_catalog.btrim(p_reason_text), ''), 500)
            else null
          end then
      raise exception 'Kle demann sa a deja itilize pou lòt done.';
    end if;

    return pg_catalog.jsonb_build_object(
      'id', v_existing.id,
      'status', v_existing.status::text,
      'kind', v_existing.kind,
      'gross_amount', v_existing.gross_amount,
      'fee_percent', v_existing.fee_percent,
      'fee_amount', v_existing.fee_amount,
      'net_amount', v_existing.net_amount,
      'authorization_mode', v_existing.authorization_mode,
      'manual_review_reason', v_existing.manual_review_reason,
      'replayed', true
    );
  end if;

  if not public.rate_limit_hit('withdrawal', 5, 300) then
    raise exception 'Twòp demann retrè. Eseye ankò nan kèk minit.';
  end if;

  v_quote := public.quote_withdrawal(p_plan_id, p_gross_amount);
  v_kind := v_quote->>'kind';
  v_fee_percent := (v_quote->>'fee_percent')::numeric;
  v_fee := (v_quote->>'fee_amount')::numeric;
  v_net := (v_quote->>'net_amount')::numeric;
  v_review_reason := nullif(v_quote->>'manual_review_reason', '');

  if p_kind is distinct from v_kind then
    raise exception 'Règ plan an chanje depi kalkil la. Rekalkile frè yo anvan ou konfime.';
  end if;
  if p_expected_fee_percent is null
     or round(p_expected_fee_percent, 2) <> round(v_fee_percent, 2) then
    raise exception 'Frè retrè a chanje. Rekalkile epi konfime ankò.';
  end if;
  if coalesce((v_quote->>'kyc_required')::boolean, false) then
    raise exception 'KYC obligatwa pou retrè sa a. Tanpri fini verifikasyon idantite a anvan ou soumèt.';
  end if;
  if v_kind = 'emergency'
     and (p_reason_category is null or p_reason_category not in ('medical','death','family_emergency','other')) then
    raise exception 'Chwazi rezon ijans lan.';
  end if;

  if coalesce((v_quote->>'manual_review')::boolean, false) then
    v_status := 'pending';
    v_mode := 'manual_review';
  else
    v_status := 'approved';
    v_mode := 'automatic';
  end if;

  insert into public.withdrawal_requests(
    plan_id, user_id, kind, reason_category, reason_text,
    gross_amount, fee_percent, fee_amount, net_amount, payment_method,
    status, authorization_mode, manual_review_reason, auto_authorized_at, idempotency_key
  ) values (
    p_plan_id, v_user, v_kind,
    case when v_kind = 'emergency' then p_reason_category else null end,
    case when v_kind = 'emergency' then left(nullif(pg_catalog.btrim(p_reason_text), ''), 500) else null end,
    round(p_gross_amount, 2), v_fee_percent, v_fee, v_net, p_payment_method,
    v_status, v_mode, v_review_reason,
    case when v_mode = 'automatic' then pg_catalog.now() else null end,
    p_idempotency_key
  ) returning id into v_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (
    v_user,
    case when v_mode = 'automatic' then 'withdrawal_auto_authorized' else 'withdrawal_held_for_review' end,
    'withdrawal_request', v_id::text,
    pg_catalog.jsonb_build_object(
      'kind', v_kind,
      'gross_amount', round(p_gross_amount, 2),
      'fee_percent', v_fee_percent,
      'fee_amount', v_fee,
      'net_amount', v_net,
      'authorization_mode', v_mode,
      'manual_review_reason', v_review_reason
    )
  );

  return pg_catalog.jsonb_build_object(
    'id', v_id,
    'status', v_status::text,
    'kind', v_kind,
    'gross_amount', round(p_gross_amount, 2),
    'fee_percent', v_fee_percent,
    'fee_amount', v_fee,
    'net_amount', v_net,
    'authorization_mode', v_mode,
    'manual_review_reason', v_review_reason,
    'replayed', false
  );
end;
$$;

revoke all on function public.request_withdrawal(uuid, numeric, text, text, text, text, numeric, uuid) from public, anon;
grant execute on function public.request_withdrawal(uuid, numeric, text, text, text, text, numeric, uuid) to authenticated;

-- Manual review is limited to risk-held and legacy requests. Payout remains a
-- separate operation, performed only after external payment has been verified.
create or replace function public.admin_review_withdrawal(
  p_request_id uuid,
  p_decision text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.withdrawal_requests%rowtype;
  v_available numeric(14,2);
begin
  if not public.is_admin() then
    raise exception 'Aksè admin obligatwa.';
  end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Desizyon an pa valab.';
  end if;

  select * into v_req
  from public.withdrawal_requests
  where id = p_request_id
  for update;
  if not found or v_req.status <> 'pending' then
    raise exception 'Demann retrè a pa disponib.';
  end if;
  if v_req.authorization_mode = 'automatic' then
    raise exception 'Retrè sa a deja otorize otomatikman.';
  end if;

  perform 1 from public.savings_plans where id = v_req.plan_id for update;
  if p_decision = 'approved' then
    select (
      coalesce((select sum(d.amount) from public.deposits d where d.plan_id = v_req.plan_id), 0)
      - coalesce((select sum(w.gross_amount) from public.withdrawal_requests w
        where w.plan_id = v_req.plan_id and w.id <> p_request_id
          and w.status in ('pending','approved','paid')), 0)
    )::numeric(14,2)
    into v_available;

    if v_req.gross_amount > v_available then
      raise exception 'Balans la pa ase pou apwouve demann sa a.';
    end if;
  end if;

  update public.withdrawal_requests
  set status = p_decision::public.withdrawal_status,
      admin_note = left(nullif(pg_catalog.btrim(p_note), ''), 500),
      reviewed_by = auth.uid(),
      reviewed_at = pg_catalog.now()
  where id = p_request_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    'withdrawal_' || p_decision,
    'withdrawal_request',
    p_request_id::text,
    pg_catalog.jsonb_build_object(
      'note', left(p_note, 200),
      'authorization_mode', v_req.authorization_mode
    )
  );
end;
$$;

revoke all on function public.admin_review_withdrawal(uuid, text, text) from public, anon;
grant execute on function public.admin_review_withdrawal(uuid, text, text) to authenticated;

comment on function public.quote_withdrawal(uuid, numeric) is
  'Quote retrè: objektif la baze sou balans aktyèl (depo mwens retrè peye); disponiblite retire rezèv yo.';
comment on function public.request_withdrawal(uuid, numeric, text, text, text, text, numeric, uuid) is
  'Kreye demann retrè idempotent; automatic approval is not external payout.';
-- ===== END 0006_kane_sa_withdrawal_hardening.sql =====

-- ===== BEGIN 0007_kane_sa_platform_modules.sql =====
-- KANÈ SA 0007: sipò kliyan, bwat notifikasyon, kontwòl ijans ak rekonsilyasyon entèn.
-- Pa aktive okenn provider peman. Kontwòl yo sispann NOUVO demann sèlman;
-- yo pa anile obligasyon ki deja egziste ni yo pa make retrè kòm peye.

-- 1) Kontwòl operasyon global
create table if not exists public.system_controls (
  id integer primary key default 1 check (id = 1),
  deposits_enabled boolean not null default true,
  withdrawal_requests_enabled boolean not null default true,
  public_notice text check (public_notice is null or char_length(public_notice) <= 320),
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);
insert into public.system_controls(id) values (1) on conflict (id) do nothing;
alter table public.system_controls enable row level security;
drop policy if exists system_controls_read_authenticated on public.system_controls;
create policy system_controls_read_authenticated on public.system_controls
  for select to authenticated using (auth.uid() is not null);
revoke all on public.system_controls from anon;
revoke insert, update, delete on public.system_controls from authenticated;
grant select on public.system_controls to authenticated;

create or replace function public.admin_set_system_controls(
  p_deposits_enabled boolean,
  p_withdrawal_requests_enabled boolean,
  p_public_notice text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_public_notice is not null and char_length(p_public_notice) > 320 then
    raise exception 'Mesaj piblik la twò long.';
  end if;
  update public.system_controls
  set deposits_enabled = p_deposits_enabled,
      withdrawal_requests_enabled = p_withdrawal_requests_enabled,
      public_notice = nullif(trim(p_public_notice), ''),
      updated_by = auth.uid(), updated_at = now()
  where id = 1;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'system_controls_updated', 'system_controls', '1',
    jsonb_build_object('deposits_enabled', p_deposits_enabled,
      'withdrawal_requests_enabled', p_withdrawal_requests_enabled,
      'notice_set', nullif(trim(p_public_notice), '') is not null));
end;
$$;
revoke all on function public.admin_set_system_controls(boolean, boolean, text) from public, anon;
grant execute on function public.admin_set_system_controls(boolean, boolean, text) to authenticated;

create or replace function public.enforce_system_deposit_switch()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_enabled boolean;
begin
  select deposits_enabled into v_enabled from public.system_controls where id = 1;
  if not coalesce(v_enabled, true) then
    raise exception using errcode = 'P0001', message = 'Demann depo yo sispann tanporèman. Lajan ki deja antre yo pa afekte.';
  end if;
  return new;
end;
$$;
create or replace function public.enforce_system_withdrawal_switch()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_enabled boolean;
begin
  select withdrawal_requests_enabled into v_enabled from public.system_controls where id = 1;
  if not coalesce(v_enabled, true) then
    raise exception using errcode = 'P0001', message = 'Nouvo demann retrè yo sispann tanporèman. Demann ki deja egziste yo rete anba pwosesis nòmal.';
  end if;
  return new;
end;
$$;
drop trigger if exists system_switch_deposit_guard on public.deposit_requests;
create trigger system_switch_deposit_guard before insert on public.deposit_requests
  for each row execute function public.enforce_system_deposit_switch();
drop trigger if exists system_switch_withdrawal_guard on public.withdrawal_requests;
create trigger system_switch_withdrawal_guard before insert on public.withdrawal_requests
  for each row execute function public.enforce_system_withdrawal_switch();

-- 2) Sipò kliyan (pa gen nòt entèn nan vèsyon sa a; tout mesaj vizib pou kliyan/admin).
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  subject text not null check (char_length(trim(subject)) between 4 and 120),
  category text not null check (category in ('account','deposit','withdrawal','savings_plan','security','other')),
  priority text not null default 'normal' check (priority in ('normal','high','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','waiting_customer','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create index if not exists support_tickets_user_created_idx on public.support_tickets(user_id, created_at desc);
create index if not exists support_tickets_status_updated_idx on public.support_tickets(status, updated_at desc);

create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists support_messages_ticket_created_idx on public.support_ticket_messages(ticket_id, created_at);

alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;
drop policy if exists support_tickets_read_related on public.support_tickets;
create policy support_tickets_read_related on public.support_tickets for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists support_messages_read_related on public.support_ticket_messages;
create policy support_messages_read_related on public.support_ticket_messages for select to authenticated
  using (exists (select 1 from public.support_tickets t where t.id = ticket_id and (t.user_id = auth.uid() or public.is_admin())));
drop policy if exists support_messages_insert_related on public.support_ticket_messages;
create policy support_messages_insert_related on public.support_ticket_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (select 1 from public.support_tickets t where t.id = ticket_id
      and ((t.user_id = auth.uid() and t.status not in ('resolved','closed')) or public.is_admin()))
  );
revoke all on public.support_tickets from anon;
revoke insert, update, delete on public.support_tickets from authenticated;
grant select on public.support_tickets to authenticated;
revoke all on public.support_ticket_messages from anon;
revoke update, delete on public.support_ticket_messages from authenticated;
grant select, insert on public.support_ticket_messages to authenticated;

create or replace function public.create_support_ticket(
  p_subject text, p_category text, p_initial_message text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_user uuid := auth.uid(); v_ticket uuid;
begin
  if v_user is null then raise exception 'Ou dwe konekte.'; end if;
  if not public.rate_limit_hit('support_ticket', 5, 3600) then
    raise exception 'Ou kreye twòp dosye sipò. Eseye ankò pita.';
  end if;
  if char_length(trim(coalesce(p_subject, ''))) not between 4 and 120 then raise exception 'Sijè a dwe gen 4 a 120 karaktè.'; end if;
  if p_category not in ('account','deposit','withdrawal','savings_plan','security','other') then raise exception 'Kategori a pa valid.'; end if;
  if char_length(trim(coalesce(p_initial_message, ''))) not between 1 and 4000 then raise exception 'Mesaj la dwe gen 1 a 4000 karaktè.'; end if;
  insert into public.support_tickets(user_id, subject, category)
  values (v_user, trim(p_subject), p_category) returning id into v_ticket;
  insert into public.support_ticket_messages(ticket_id, sender_id, body)
  values (v_ticket, v_user, trim(p_initial_message));
  return v_ticket;
end;
$$;

create or replace function public.admin_update_support_ticket(
  p_ticket_id uuid, p_status text, p_reply text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_status not in ('open','in_progress','waiting_customer','resolved','closed') then raise exception 'Estati dosye a pa valid.'; end if;
  if p_reply is not null and char_length(trim(p_reply)) not between 1 and 4000 then raise exception 'Repons lan dwe gen 1 a 4000 karaktè.'; end if;
  update public.support_tickets set status = p_status, updated_at = now(), last_message_at = case when p_reply is not null then now() else last_message_at end
  where id = p_ticket_id;
  if not found then raise exception 'Dosye sipò a pa egziste.'; end if;
  if p_reply is not null then
    insert into public.support_ticket_messages(ticket_id, sender_id, body)
    values (p_ticket_id, auth.uid(), trim(p_reply));
  end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'support_ticket_updated', 'support_ticket', p_ticket_id::text,
    jsonb_build_object('status', p_status, 'reply_added', p_reply is not null));
end;
$$;
revoke all on function public.create_support_ticket(text, text, text) from public, anon;
grant execute on function public.create_support_ticket(text, text, text) to authenticated;
revoke all on function public.admin_update_support_ticket(uuid, text, text) from public, anon;
grant execute on function public.admin_update_support_ticket(uuid, text, text) to authenticated;

create or replace function public.touch_support_ticket()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() and not public.rate_limit_hit('support_message', 20, 3600) then
    raise exception 'Ou voye twòp mesaj sipò. Eseye ankò pita.';
  end if;
  update public.support_tickets set updated_at = now(), last_message_at = now() where id = new.ticket_id;
  return new;
end;
$$;
drop trigger if exists support_message_touch_ticket on public.support_ticket_messages;
create trigger support_message_touch_ticket after insert on public.support_ticket_messages
  for each row execute function public.touch_support_ticket();

-- 3) Bwat notifikasyon anndan app la. Push rete opsyonèl e li pa obligatwa pou tranzaksyon.
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('deposit','withdrawal','support','security','system')),
  title text not null check (char_length(title) between 2 and 120),
  body text not null check (char_length(body) between 1 and 500),
  href text not null default '/tableau-de-bord' check (href like '/%'),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists user_notifications_user_created_idx on public.user_notifications(user_id, created_at desc);
create index if not exists user_notifications_unread_idx on public.user_notifications(user_id, created_at desc) where read_at is null;
alter table public.user_notifications enable row level security;
drop policy if exists user_notifications_read_self on public.user_notifications;
create policy user_notifications_read_self on public.user_notifications for select to authenticated using (user_id = auth.uid());
revoke all on public.user_notifications from anon;
revoke insert, update, delete on public.user_notifications from authenticated;
grant select on public.user_notifications to authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Ou dwe konekte.'; end if;
  update public.user_notifications set read_at = coalesce(read_at, now())
  where id = p_notification_id and user_id = auth.uid();
end;
$$;
revoke all on function public.mark_notification_read(uuid) from public, anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.notify_deposit_request_created()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.user_notifications(user_id, kind, title, body, href)
  values (new.user_id, 'deposit', 'Demann depo resevwa', 'Nou resevwa demann depo ou a. Li poko antre nan balans lan.', '/historique');
  return new;
end;
$$;
create or replace function public.notify_deposit_confirmed()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.user_notifications(user_id, kind, title, body, href)
  values (new.user_id, 'deposit', 'Depo konfime', 'Administrasyon konfime depo ou a. Balans plan an mete ajou.', '/historique');
  return new;
end;
$$;
create or replace function public.notify_deposit_rejected()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if old.status is distinct from new.status and new.status = 'rejected' then
    insert into public.user_notifications(user_id, kind, title, body, href)
    values (new.user_id, 'deposit', 'Demann depo pa valide', 'Demann depo a pa te konfime. Louvri istorik la pou plis detay.', '/historique');
  end if;
  return new;
end;
$$;
create or replace function public.notify_withdrawal_created()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.user_notifications(user_id, kind, title, body, href)
  values (new.user_id, 'withdrawal',
    case when new.status = 'approved' then 'Retrè otorize' else 'Retrè an verifikasyon' end,
    case when new.status = 'approved' then 'Demann retrè a otorize anndan KANÈ SA. Peman an poko konfime.' else 'Demann retrè a bezwen revizyon sekirite anvan desizyon.' end,
    '/historique');
  return new;
end;
$$;
create or replace function public.notify_withdrawal_status_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_title text; v_body text;
begin
  if old.status is distinct from new.status then
    if new.status = 'paid' then
      v_title := 'Retrè make kòm peye'; v_body := 'Peman retrè a make kòm fèt apre verifikasyon referans lan.';
    elsif new.status = 'rejected' then
      v_title := 'Demann retrè rejte'; v_body := 'Demann retrè a pa te apwouve. Kontakte sipò si ou bezwen plis detay.';
    elsif new.status = 'approved' then
      v_title := 'Retrè otorize'; v_body := 'Demann retrè a otorize anndan sistèm nan. Peman an poko konfime.';
    else
      v_title := 'Mizajou sou retrè'; v_body := 'Estati demann retrè ou a chanje.';
    end if;
    insert into public.user_notifications(user_id, kind, title, body, href)
    values (new.user_id, 'withdrawal', v_title, v_body, '/historique');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_deposit_request_insert on public.deposit_requests;
create trigger notify_deposit_request_insert after insert on public.deposit_requests
  for each row execute function public.notify_deposit_request_created();
drop trigger if exists notify_deposit_insert on public.deposits;
create trigger notify_deposit_insert after insert on public.deposits
  for each row execute function public.notify_deposit_confirmed();
drop trigger if exists notify_deposit_reject on public.deposit_requests;
create trigger notify_deposit_reject after update on public.deposit_requests
  for each row execute function public.notify_deposit_rejected();
drop trigger if exists notify_withdrawal_insert on public.withdrawal_requests;
create trigger notify_withdrawal_insert after insert on public.withdrawal_requests
  for each row execute function public.notify_withdrawal_created();
drop trigger if exists notify_withdrawal_update on public.withdrawal_requests;
create trigger notify_withdrawal_update after update on public.withdrawal_requests
  for each row execute function public.notify_withdrawal_status_change();

create or replace function public.notify_customer_support_reply()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_owner uuid; v_sender_role public.app_role;
begin
  select role into v_sender_role from public.profiles where id = new.sender_id;
  if v_sender_role = 'admin' then
    select user_id into v_owner from public.support_tickets where id = new.ticket_id;
    if v_owner is not null then
      insert into public.user_notifications(user_id, kind, title, body, href)
      values (v_owner, 'support', 'Nouvo repons sipò', 'Ekip KANÈ SA reponn dosye sipò ou a.', '/sipo');
    end if;
  else
    insert into public.user_notifications(user_id, kind, title, body, href)
    select p.id, 'support', 'Nouvo mesaj kliyan', 'Yon kliyan voye yon mesaj nan sant sipò a.', '/admin/sipo'
    from public.profiles p where p.role = 'admin';
  end if;
  return new;
end;
$$;
create or replace function public.notify_support_ticket_status_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if old.status is distinct from new.status then
    insert into public.user_notifications(user_id, kind, title, body, href)
    values (new.user_id, 'support', 'Estati dosye sipò a chanje', 'Ekip KANÈ SA mete estati dosye ou a ajou.', '/sipo');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_customer_support_reply_insert on public.support_ticket_messages;
create trigger notify_customer_support_reply_insert after insert on public.support_ticket_messages
  for each row execute function public.notify_customer_support_reply();
drop trigger if exists notify_support_ticket_status_update on public.support_tickets;
create trigger notify_support_ticket_status_update after update on public.support_tickets
  for each row execute function public.notify_support_ticket_status_change();

-- 4) Rekonsilyasyon sa a verifye kontablite entèn lan. Li pa konpare ak MonCash/NatCash/bank.
create or replace view public.admin_reconciliation_checks with (security_barrier = true) as
select c.check_name, c.violations, c.severity
from (
  select 'negative_balance'::text as check_name, count(*)::int as violations, 'critical'::text as severity
  from public.plan_balances where balance < 0
  union all
  select 'negative_available_balance', count(*)::int, 'critical'::text from public.plan_balances where available_balance < 0
  union all
  select 'ledger_unbalanced', count(*)::int, 'critical'::text
  from (select txn_id from public.ledger_entries group by txn_id having sum(debit) <> sum(credit)) x
  union all
  select 'deposit_missing_ledger', count(*)::int, 'high'::text
  from public.deposits d where not exists (
    select 1 from public.ledger_entries l where l.ref_type = 'deposit' and l.ref_id = d.id and l.account = 'customer_liability'
  )
  union all
  select 'paid_withdrawal_missing_ledger', count(*)::int, 'high'::text
  from public.withdrawal_requests w where w.status = 'paid' and not exists (
    select 1 from public.ledger_entries l where l.ref_type = 'withdrawal' and l.ref_id = w.id and l.account = 'customer_liability'
  )
  union all
  select 'ledger_plan_balance_mismatch', count(*)::int, 'critical'::text
  from public.plan_balances b where round(b.balance, 2) <> round(coalesce((
    select sum(l.credit - l.debit) from public.ledger_entries l
    where l.plan_id = b.plan_id and l.account = 'customer_liability'
  ), 0), 2)
) c
where public.is_admin();
grant select on public.admin_reconciliation_checks to authenticated;

-- 5) Rate limits limite yo rete anba kontwòl sèvè a; kliyan pa ka chwazi kota yo.
create or replace function public.rate_limit_hit(p_key text, p_max integer, p_window_seconds integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit public.rate_limits%rowtype;
  v_allowed_max integer;
  v_allowed_window integer;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then return false; end if;
  case p_key
    when 'deposit' then v_allowed_max := 10; v_allowed_window := 60;
    when 'tx' then v_allowed_max := 30; v_allowed_window := 60;
    when 'withdrawal_quote' then v_allowed_max := 30; v_allowed_window := 60;
    when 'withdrawal' then v_allowed_max := 5; v_allowed_window := 300;
    when 'support_ticket' then v_allowed_max := 5; v_allowed_window := 3600;
    when 'support_message' then v_allowed_max := 20; v_allowed_window := 3600;
    else raise exception 'Kle limit sa a pa otorize.';
  end case;
  if p_max is distinct from v_allowed_max or p_window_seconds is distinct from v_allowed_window then
    raise exception 'Paramèt rate limit sa yo pa otorize.';
  end if;
  insert into public.rate_limits(key, window_start, hits)
  values (v_user_id::text || ':' || p_key, pg_catalog.now(), 1)
  on conflict (key) do update set
    hits = case when public.rate_limits.window_start < pg_catalog.now() - pg_catalog.make_interval(secs => p_window_seconds) then 1 else public.rate_limits.hits + 1 end,
    window_start = case when public.rate_limits.window_start < pg_catalog.now() - pg_catalog.make_interval(secs => p_window_seconds) then pg_catalog.now() else public.rate_limits.window_start end
  returning * into v_limit;
  return v_limit.hits <= v_allowed_max;
end;
$$;
revoke all on function public.rate_limit_hit(text, integer, integer) from public, anon;
grant execute on function public.rate_limit_hit(text, integer, integer) to authenticated;

comment on table public.system_controls is 'Kontwòl operasyon pou sispann nouvo demann depo/retrè; pa ranplase pwosesis peman.';
comment on table public.support_tickets is 'Dosye sipò kliyan. Mesaj nan MVP sa a vizib pou kliyan ki louvri dosye a ak admin.';
comment on view public.admin_reconciliation_checks is 'Kontwòl ledger entèn; pa yon rekonsilyasyon ekstèn provider/bank.';

-- ===== END 0007_kane_sa_platform_modules.sql =====










-- ===== BEGIN 0008_kane_sa_real_money_scaffold.sql =====
-- KANÈ SA 0008: prepare enfrastrikti lajan reyèl san aktive okenn mouvman lajan.
-- Sekirite: mòd reyèl, depo provider, payout provider ak sandbox rete fèmen nan bazdone a.
-- Pou retire verrou sa yo pita, mande yon nouvo migration apre entegrasyon + odit + apwobasyon.

-- 1) Verrou global lajan. CHECK yo fè li enposib pou yon UPDATE senp aktive mòd la.
create table if not exists public.money_rail_controls (
  id int primary key default 1 check (id = 1),
  live_money_enabled boolean not null default false check (live_money_enabled = false),
  inbound_enabled boolean not null default false check (inbound_enabled = false),
  outbound_enabled boolean not null default false check (outbound_enabled = false),
  sandbox_enabled boolean not null default false check (sandbox_enabled = false),
  kill_switch boolean not null default true check (kill_switch = true),
  locked_reason text not null default 'Entegrasyon peman, konfòmite ak tès yo poko apwouve.',
  updated_at timestamptz not null default now()
);
insert into public.money_rail_controls(id) values (1) on conflict (id) do nothing;
alter table public.money_rail_controls enable row level security;
drop policy if exists money_rail_controls_admin_read on public.money_rail_controls;
create policy money_rail_controls_admin_read on public.money_rail_controls
  for select to authenticated using (public.is_admin());
revoke all on public.money_rail_controls from public, anon, authenticated;
grant select on public.money_rail_controls to authenticated;
grant all on public.money_rail_controls to service_role;

-- 2) Rejis provider. Pa gen kolòn pou sekrè, token, PIN oswa kle prive.
create table if not exists public.money_provider_accounts (
  provider text primary key check (provider in ('moncash','natcash','bank')),
  display_name text not null,
  enabled boolean not null default false check (enabled = false),
  environment text not null default 'disabled' check (environment = 'disabled'),
  credentials_present boolean not null default false check (credentials_present = false),
  sandbox_verified boolean not null default false check (sandbox_verified = false),
  live_verified boolean not null default false check (live_verified = false),
  inbound_enabled boolean not null default false check (inbound_enabled = false),
  outbound_enabled boolean not null default false check (outbound_enabled = false),
  merchant_reference text,
  webhook_url_configured boolean not null default false check (webhook_url_configured = false),
  webhook_signature_verified boolean not null default false check (webhook_signature_verified = false),
  last_checked_at timestamptz,
  updated_at timestamptz not null default now()
);
insert into public.money_provider_accounts(provider, display_name) values
  ('moncash','MonCash'), ('natcash','NatCash'), ('bank','Bank / patnè bankè')
on conflict (provider) do nothing;
alter table public.money_provider_accounts enable row level security;
drop policy if exists money_provider_accounts_admin_read on public.money_provider_accounts;
create policy money_provider_accounts_admin_read on public.money_provider_accounts
  for select to authenticated using (public.is_admin());
revoke all on public.money_provider_accounts from public, anon, authenticated;
grant select on public.money_provider_accounts to authenticated;
grant all on public.money_provider_accounts to service_role;

-- 3) Entansyon peman inbound. Yon entansyon pa janm egal ak yon depo konfime.
create table if not exists public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  direction text not null check (direction in ('inbound','outbound')),
  provider text not null references public.money_provider_accounts(provider),
  deposit_request_id uuid references public.deposit_requests(id) on delete restrict,
  withdrawal_request_id uuid references public.withdrawal_requests(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0 and amount <= 10000000),
  currency text not null default 'HTG' check (currency = 'HTG'),
  status text not null default 'staged' check (status = 'staged'),
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 128),
  provider_reference text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check ((direction = 'inbound' and deposit_request_id is not null and withdrawal_request_id is null)
      or (direction = 'outbound' and withdrawal_request_id is not null and deposit_request_id is null))
);
create unique index if not exists payment_intents_deposit_unique on public.payment_intents(deposit_request_id) where deposit_request_id is not null;
create unique index if not exists payment_intents_withdrawal_unique on public.payment_intents(withdrawal_request_id) where withdrawal_request_id is not null;
create unique index if not exists payment_intents_provider_reference_unique on public.payment_intents(provider, provider_reference) where provider_reference is not null;
create index if not exists payment_intents_created_idx on public.payment_intents(created_at desc);
alter table public.payment_intents enable row level security;
drop policy if exists payment_intents_admin_read on public.payment_intents;
create policy payment_intents_admin_read on public.payment_intents for select to authenticated using (public.is_admin());
revoke all on public.payment_intents from public, anon, authenticated;
grant select on public.payment_intents to authenticated;
grant all on public.payment_intents to service_role;

-- 4) Tantativ payout. Status la rete 'staged' jouk yon nouvo migration retire verrou a.
create table if not exists public.payout_attempts (
  id uuid primary key default gen_random_uuid(),
  withdrawal_request_id uuid not null references public.withdrawal_requests(id) on delete restrict,
  provider text not null references public.money_provider_accounts(provider),
  attempt_number int not null default 1 check (attempt_number between 1 and 20),
  amount numeric(14,2) not null check (amount > 0 and amount <= 10000000),
  currency text not null default 'HTG' check (currency = 'HTG'),
  status text not null default 'staged' check (status = 'staged'),
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 128),
  provider_reference text,
  provider_transaction_id text,
  failure_code text,
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  completed_at timestamptz,
  unique(withdrawal_request_id, attempt_number),
  unique(provider, provider_transaction_id)
);
create index if not exists payout_attempts_withdrawal_idx on public.payout_attempts(withdrawal_request_id, created_at desc);
alter table public.payout_attempts enable row level security;
drop policy if exists payout_attempts_admin_read on public.payout_attempts;
create policy payout_attempts_admin_read on public.payout_attempts for select to authenticated using (public.is_admin());
revoke all on public.payout_attempts from public, anon, authenticated;
grant select on public.payout_attempts to authenticated;
grant all on public.payout_attempts to service_role;

-- 5) Inbox webhook. Pa konsève body HTTP brit; se sèlman hash ak metadata ki ka konsève.
create table if not exists public.provider_webhook_inbox (
  id uuid primary key default gen_random_uuid(),
  provider text not null references public.money_provider_accounts(provider),
  provider_event_id text not null check (length(provider_event_id) between 1 and 200),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  signature_verified boolean not null default false check (signature_verified = false),
  processing_status text not null default 'blocked' check (processing_status = 'blocked'),
  received_at timestamptz not null default now(),
  unique(provider, provider_event_id)
);
create index if not exists provider_webhook_inbox_received_idx on public.provider_webhook_inbox(received_at desc);
alter table public.provider_webhook_inbox enable row level security;
drop policy if exists provider_webhook_inbox_admin_read on public.provider_webhook_inbox;
create policy provider_webhook_inbox_admin_read on public.provider_webhook_inbox for select to authenticated using (public.is_admin());
revoke all on public.provider_webhook_inbox from public, anon, authenticated;
grant select on public.provider_webhook_inbox to authenticated;
grant all on public.provider_webhook_inbox to service_role;

-- 6) Enpòte deklarasyon provider ak liy yo pou rekonsilyasyon ekstèn pita.
create table if not exists public.provider_settlement_batches (
  id uuid primary key default gen_random_uuid(),
  provider text not null references public.money_provider_accounts(provider),
  statement_reference text,
  period_start date not null,
  period_end date not null,
  currency text not null default 'HTG' check (currency = 'HTG'),
  inbound_total numeric(16,2) not null default 0 check (inbound_total >= 0),
  outbound_total numeric(16,2) not null default 0 check (outbound_total >= 0),
  fees_total numeric(16,2) not null default 0 check (fees_total >= 0),
  file_sha256 text check (file_sha256 is null or file_sha256 ~ '^[0-9a-f]{64}$'),
  status text not null default 'staged' check (status = 'staged'),
  imported_by uuid references public.profiles(id),
  imported_at timestamptz not null default now(),
  check (period_end >= period_start)
);
create unique index if not exists provider_settlement_file_hash_unique on public.provider_settlement_batches(provider, file_sha256) where file_sha256 is not null;
create table if not exists public.provider_settlement_entries (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.provider_settlement_batches(id) on delete restrict,
  provider text not null references public.money_provider_accounts(provider),
  external_transaction_id text not null check (length(external_transaction_id) between 1 and 200),
  direction text not null check (direction in ('inbound','outbound','fee','adjustment')),
  amount numeric(14,2) not null check (amount >= 0),
  currency text not null default 'HTG' check (currency = 'HTG'),
  occurred_at timestamptz,
  internal_reference text,
  match_status text not null default 'not_reconciled' check (match_status = 'not_reconciled'),
  created_at timestamptz not null default now(),
  unique(provider, external_transaction_id)
);
create index if not exists provider_settlement_entries_batch_idx on public.provider_settlement_entries(batch_id, created_at);
alter table public.provider_settlement_batches enable row level security;
alter table public.provider_settlement_entries enable row level security;
drop policy if exists provider_settlement_batches_admin_read on public.provider_settlement_batches;
drop policy if exists provider_settlement_entries_admin_read on public.provider_settlement_entries;
create policy provider_settlement_batches_admin_read on public.provider_settlement_batches for select to authenticated using (public.is_admin());
create policy provider_settlement_entries_admin_read on public.provider_settlement_entries for select to authenticated using (public.is_admin());
revoke all on public.provider_settlement_batches, public.provider_settlement_entries from public, anon, authenticated;
grant select on public.provider_settlement_batches, public.provider_settlement_entries to authenticated;
grant all on public.provider_settlement_batches, public.provider_settlement_entries to service_role;

-- 7) Verrou mòd live ki te egziste nan migration 0004. Tout admin toggle live yo refize.
update public.compliance_settings set live_mode = false where id = 1;
alter table public.compliance_settings drop constraint if exists compliance_settings_live_money_hard_off;
alter table public.compliance_settings add constraint compliance_settings_live_money_hard_off check (live_mode = false);

create or replace function public.admin_set_live_mode(p_live boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  if p_live then
    raise exception 'Mòd lajan reyèl la fèmen nan vèsyon sa a. Li mande yon nouvo migration, entegrasyon, odit ak apwobasyon separe.';
  end if;
  update public.compliance_settings set live_mode = false where id = 1;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'live_mode_disabled', 'settings', null, jsonb_build_object('live', false, 'reason', 'hard_lock_v1_7'));
end;
$$;
revoke all on function public.admin_set_live_mode(boolean) from public, anon;
grant execute on function public.admin_set_live_mode(boolean) to authenticated;

create or replace function public.admin_set_gate(p_key text, p_done boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_label text;
begin
  if not public.is_admin() then raise exception 'Aksè admin sèlman.'; end if;
  update public.go_live_gates
  set done = p_done, done_by = case when p_done then auth.uid() end, done_at = case when p_done then now() end
  where key = p_key returning label into v_label;
  if not found then raise exception 'Pòtay lansman sa a pa egziste.'; end if;
  if not p_done then update public.compliance_settings set live_mode = false where id = 1; end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'go_live_gate_updated', 'go_live_gate', p_key,
    jsonb_build_object('done', p_done, 'label', v_label));
end;
$$;
revoke all on function public.admin_set_gate(text, boolean) from public, anon;
grant execute on function public.admin_set_gate(text, boolean) to authenticated;

comment on table public.money_rail_controls is 'Verrou mwayen peman KANÈ SA. Tout boolean activation rete false jiskaske yon migration release apa.';
comment on table public.money_provider_accounts is 'Rejis provider san okenn sekrè. MonCash/NatCash/bank rete dezaktive.';
comment on table public.payment_intents is 'Espas preparasyon demann peman. Status staged sèlman; li pa prèv tranzaksyon.';
comment on table public.payout_attempts is 'Espas preparasyon payout. Status staged sèlman; li pa voye lajan.';
comment on table public.provider_webhook_inbox is 'Webhook inbox preparasyon; pa gen payload brit, signature_verified rete false.';
comment on table public.provider_settlement_batches is 'Deklarasyon provider pou rekonsilyasyon ekstèn pita; status staged sèlman.';

-- 8) Verifye chak intent/payout kont demann orijinal la anvan yon backend privilejye ka ekri li.
create or replace function public.validate_payment_intent_target()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_amount numeric(14,2); v_method text; v_status text;
begin
  if new.direction = 'inbound' then
    select d.amount, d.method, d.status::text into v_amount, v_method, v_status
    from public.deposit_requests d where d.id = new.deposit_request_id;
    if not found then raise exception 'Demann depo ki mare ak intent la pa egziste.'; end if;
    if v_status <> 'pending' then raise exception 'Se sèlman yon demann depo an atant ki ka resevwa yon intent.'; end if;
  else
    select w.net_amount, w.payment_method, w.status::text into v_amount, v_method, v_status
    from public.withdrawal_requests w where w.id = new.withdrawal_request_id;
    if not found then raise exception 'Demann retrè ki mare ak intent la pa egziste.'; end if;
    if v_status <> 'approved' then raise exception 'Se sèlman retrè ki otorize ki ka resevwa yon intent payout.'; end if;
  end if;
  if new.provider is distinct from v_method then raise exception 'Provider intent la pa koresponn ak metòd demann lan.'; end if;
  if round(new.amount,2) <> round(v_amount,2) then raise exception 'Montan intent la pa koresponn ak demann orijinal la.'; end if;
  return new;
end;
$$;
drop trigger if exists payment_intent_target_guard on public.payment_intents;
create trigger payment_intent_target_guard before insert or update on public.payment_intents
  for each row execute function public.validate_payment_intent_target();

create or replace function public.validate_payout_attempt_target()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_amount numeric(14,2); v_method text; v_status text;
begin
  select w.net_amount, w.payment_method, w.status::text into v_amount, v_method, v_status
  from public.withdrawal_requests w where w.id = new.withdrawal_request_id;
  if not found then raise exception 'Demann retrè payout la pa egziste.'; end if;
  if v_status <> 'approved' then raise exception 'Payout kapab prepare sèlman pou retrè ki otorize.'; end if;
  if new.provider is distinct from v_method then raise exception 'Provider payout la pa koresponn ak metòd kliyan an.'; end if;
  if round(new.amount,2) <> round(v_amount,2) then raise exception 'Montan payout la pa koresponn ak montan net retrè a.'; end if;
  return new;
end;
$$;
drop trigger if exists payout_attempt_target_guard on public.payout_attempts;
create trigger payout_attempt_target_guard before insert or update on public.payout_attempts
  for each row execute function public.validate_payout_attempt_target();

create or replace function public.validate_settlement_entry_provider()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_provider text;
begin
  select b.provider into v_provider from public.provider_settlement_batches b where b.id = new.batch_id;
  if not found then raise exception 'Deklarasyon provider la pa egziste.'; end if;
  if new.provider is distinct from v_provider then raise exception 'Provider liy deklarasyon an pa koresponn ak batch la.'; end if;
  return new;
end;
$$;
drop trigger if exists settlement_entry_provider_guard on public.provider_settlement_entries;
create trigger settlement_entry_provider_guard before insert or update on public.provider_settlement_entries
  for each row execute function public.validate_settlement_entry_provider();

revoke all on function public.validate_payment_intent_target(), public.validate_payout_attempt_target(), public.validate_settlement_entry_provider() from public, anon, authenticated;

-- 9) Rekonsilyasyon provider ak lis eksepsyon yo (staging sèlman nan vèsyon sa a).
create table if not exists public.provider_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  provider text not null references public.money_provider_accounts(provider),
  settlement_batch_id uuid not null references public.provider_settlement_batches(id) on delete restrict,
  status text not null default 'staged' check (status = 'staged'),
  matched_count int not null default 0 check (matched_count >= 0),
  unmatched_count int not null default 0 check (unmatched_count >= 0),
  mismatched_count int not null default 0 check (mismatched_count >= 0),
  difference_total numeric(16,2) not null default 0,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.provider_reconciliation_issues (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.provider_reconciliation_runs(id) on delete restrict,
  statement_entry_id uuid references public.provider_settlement_entries(id) on delete restrict,
  issue_code text not null check (issue_code in ('provider_only','internal_only','amount_mismatch','currency_mismatch','duplicate_reference','status_mismatch')),
  internal_reference text,
  external_transaction_id text,
  internal_amount numeric(14,2),
  external_amount numeric(14,2),
  status text not null default 'open' check (status = 'open'),
  created_at timestamptz not null default now()
);
create index if not exists provider_reconciliation_runs_batch_idx on public.provider_reconciliation_runs(settlement_batch_id, created_at desc);
create index if not exists provider_reconciliation_issues_run_idx on public.provider_reconciliation_issues(run_id, created_at desc);
alter table public.provider_reconciliation_runs enable row level security;
alter table public.provider_reconciliation_issues enable row level security;
drop policy if exists provider_reconciliation_runs_admin_read on public.provider_reconciliation_runs;
drop policy if exists provider_reconciliation_issues_admin_read on public.provider_reconciliation_issues;
create policy provider_reconciliation_runs_admin_read on public.provider_reconciliation_runs for select to authenticated using (public.is_admin());
create policy provider_reconciliation_issues_admin_read on public.provider_reconciliation_issues for select to authenticated using (public.is_admin());
revoke all on public.provider_reconciliation_runs, public.provider_reconciliation_issues from public, anon, authenticated;
grant select on public.provider_reconciliation_runs, public.provider_reconciliation_issues to authenticated;
grant all on public.provider_reconciliation_runs, public.provider_reconciliation_issues to service_role;

create or replace function public.validate_provider_reconciliation_run()
returns trigger language plpgsql set search_path = '' as $$
declare v_provider text;
begin
  select b.provider into v_provider from public.provider_settlement_batches b where b.id = new.settlement_batch_id;
  if not found then raise exception 'Batch rekonsilyasyon an pa egziste.'; end if;
  if new.provider is distinct from v_provider then raise exception 'Provider run lan pa koresponn ak batch deklarasyon an.'; end if;
  return new;
end;
$$;
drop trigger if exists provider_reconciliation_run_guard on public.provider_reconciliation_runs;
create trigger provider_reconciliation_run_guard before insert or update on public.provider_reconciliation_runs
  for each row execute function public.validate_provider_reconciliation_run();

create or replace function public.validate_provider_reconciliation_issue()
returns trigger language plpgsql set search_path = '' as $$
declare v_batch uuid;
begin
  if new.statement_entry_id is not null then
    select r.settlement_batch_id into v_batch
    from public.provider_reconciliation_runs r where r.id = new.run_id;
    if not found then raise exception 'Run rekonsilyasyon an pa egziste.'; end if;
    if not exists (select 1 from public.provider_settlement_entries e where e.id = new.statement_entry_id and e.batch_id = v_batch) then
      raise exception 'Liy deklarasyon an pa fè pati batch rekonsilyasyon sa a.';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists provider_reconciliation_issue_guard on public.provider_reconciliation_issues;
create trigger provider_reconciliation_issue_guard before insert or update on public.provider_reconciliation_issues
  for each row execute function public.validate_provider_reconciliation_issue();

revoke all on function public.validate_provider_reconciliation_run(), public.validate_provider_reconciliation_issue() from public, anon, authenticated;

-- Yon sèl attempt staged pou chak retrè; nouvo attempt mande yon nouvo workflow/release.
create unique index if not exists payout_attempts_one_staged_per_withdrawal
  on public.payout_attempts(withdrawal_request_id) where status = 'staged';

create or replace function public.prevent_money_rail_control_delete()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'Verrou finansye a pa ka efase.';
end;
$$;
drop trigger if exists money_rail_control_no_delete on public.money_rail_controls;
create trigger money_rail_control_no_delete before delete on public.money_rail_controls
  for each row execute function public.prevent_money_rail_control_delete();
revoke all on function public.prevent_money_rail_control_delete() from public, anon, authenticated;

comment on table public.provider_reconciliation_runs is 'Run rekonsilyasyon provider pou pita; status staged sèlman.';
comment on table public.provider_reconciliation_issues is 'Eksepsyon rekonsilyasyon ekstèn pou revizyon pita; status open sèlman.';

-- ===== END 0008_kane_sa_real_money_scaffold.sql =====
