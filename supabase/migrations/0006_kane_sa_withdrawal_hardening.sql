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
