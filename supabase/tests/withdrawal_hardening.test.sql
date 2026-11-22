-- pgTAP: objective status uses actual balance and quotas cannot be caller-inflated.
begin;
select plan(6);

insert into auth.users(id, email) values
  ('00000000-0000-0000-0000-0000000000a6','admin-hardening@test.local'),
  ('00000000-0000-0000-0000-0000000000b6','client-hardening@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000a6';

insert into public.savings_plans(id, user_id, title, has_goal, goal_amount) values
  ('00000000-0000-0000-0000-0000000000c6','00000000-0000-0000-0000-0000000000b6','Objektif deja rive',true,1000);
insert into public.deposit_requests(id, plan_id, user_id, method, amount) values
  ('00000000-0000-0000-0000-0000000000d6','00000000-0000-0000-0000-0000000000c6','00000000-0000-0000-0000-0000000000b6','cash',1000);
insert into public.deposits(id, plan_id, user_id, deposit_request_id, amount, method, confirmed_by) values
  ('00000000-0000-0000-0000-0000000000e6','00000000-0000-0000-0000-0000000000c6','00000000-0000-0000-0000-0000000000b6','00000000-0000-0000-0000-0000000000d6',1000,'cash','00000000-0000-0000-0000-0000000000a6');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000b6',true);

select is((public.request_withdrawal(
  '00000000-0000-0000-0000-0000000000c6',100,'normal',null,null,'cash',0,
  '00000000-0000-0000-0000-0000000000f6'
)->>'status'),'approved','premye retrè sou objektif rive jwenn otorizasyon otomatik');

select throws_ok($$select public.request_withdrawal(
  '00000000-0000-0000-0000-0000000000c6',101,'normal',null,null,'cash',0,
  '00000000-0000-0000-0000-0000000000f6'
)$$,'P0001','Kle demann sa a deja itilize pou lòt done.',
  'menm kle idempotency la pa ka itilize pou yon lòt montan');

select is(public.quote_withdrawal('00000000-0000-0000-0000-0000000000c6',100)->>'kind',
  'normal','rezèv retrè apwouve pa fè objektif ki deja rive tounen ijans');
select is(public.quote_withdrawal('00000000-0000-0000-0000-0000000000c6',100)->>'goal_reached',
  'true','objektif la mezire sou balans aktyèl, pa sou balans disponib apre rezèv');
select lives_ok($$select public.rate_limit_hit('deposit',10,60)$$,
  'limit depo a ak quota fiks lan fonksyone');
select throws_ok($$select public.rate_limit_hit('deposit',999999,60)$$,
  'P0001','Paramèt rate limit sa yo pa otorize.',
  'kliyan pa kapab ogmante pwòp kota rate limit li');

select * from finish();
rollback;
