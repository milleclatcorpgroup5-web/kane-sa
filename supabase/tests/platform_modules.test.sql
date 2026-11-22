begin;
select plan(12);

select has_table('public', 'system_controls', 'kontwòl global la egziste');
select has_table('public', 'support_tickets', 'tab sipò kliyan an egziste');
select has_table('public', 'support_ticket_messages', 'tab mesaj sipò a egziste');
select has_table('public', 'user_notifications', 'bwat notifikasyon an egziste');
select has_view('public', 'admin_reconciliation_checks', 'view rekonsilyasyon entèn lan egziste');
select has_function('public', 'admin_set_system_controls', ARRAY['boolean','boolean','text'], 'fonksyon kontwòl global admin lan egziste');
select is((select deposits_enabled from public.system_controls where id = 1), true, 'depo yo rete aktive pa defo');
select is((select withdrawal_requests_enabled from public.system_controls where id = 1), true, 'nouvo demann retrè yo rete aktive pa defo');

insert into auth.users(id, email) values
  ('00000000-0000-0000-0000-0000000007a1', 'admin-platform@test.local'),
  ('00000000-0000-0000-0000-0000000007b1', 'client-platform@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000007a1';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000007b1',true);
select ok(public.create_support_ticket('Kesyon sou kont', 'account', 'Mwen bezwen asistans sou kont mwen.') is not null,
  'kliyan an kapab kreye yon dosye sipò');
select is((select count(*)::int from public.support_tickets where user_id = '00000000-0000-0000-0000-0000000007b1'), 1,
  'dosye sipò a konsève nan baz done a');

insert into public.savings_plans(id, user_id, title) values
  ('00000000-0000-0000-0000-0000000007c1','00000000-0000-0000-0000-0000000007b1','Plan switch tès');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000007a1',true);
select public.admin_set_system_controls(false, false, 'Antretyen tès');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000007b1',true);
select throws_ok($$insert into public.deposit_requests(plan_id,user_id,method,amount) values
  ('00000000-0000-0000-0000-0000000007c1','00000000-0000-0000-0000-0000000007b1','cash',100)$$,
  'P0001','Demann depo yo sispann tanporèman. Lajan ki deja antre yo pa afekte.',
  'switch bazdone a bloke nouvo demann depo');
select throws_ok($$insert into public.withdrawal_requests(plan_id,user_id,kind,gross_amount,fee_percent,fee_amount,net_amount) values
  ('00000000-0000-0000-0000-0000000007c1','00000000-0000-0000-0000-0000000007b1','normal',100,0,0,100)$$,
  'P0001','Nouvo demann retrè yo sispann tanporèman. Demann ki deja egziste yo rete anba pwosesis nòmal.',
  'switch bazdone a bloke nouvo demann retrè');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000007a1',true);
select public.admin_set_system_controls(true, true, null);

rollback;
