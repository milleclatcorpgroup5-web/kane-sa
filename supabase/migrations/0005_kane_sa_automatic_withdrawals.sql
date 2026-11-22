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
