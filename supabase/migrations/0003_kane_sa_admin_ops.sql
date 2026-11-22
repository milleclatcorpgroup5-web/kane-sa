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
