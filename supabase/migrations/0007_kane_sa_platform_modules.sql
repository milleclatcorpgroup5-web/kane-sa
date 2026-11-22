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
