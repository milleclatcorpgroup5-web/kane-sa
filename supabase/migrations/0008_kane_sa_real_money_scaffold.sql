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
