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
create trigger aml_deposit_screen after insert on public.deposit_requests for each row execute function public.aml_screen();
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
