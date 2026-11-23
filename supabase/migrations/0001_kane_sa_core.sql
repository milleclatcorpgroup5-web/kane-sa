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
