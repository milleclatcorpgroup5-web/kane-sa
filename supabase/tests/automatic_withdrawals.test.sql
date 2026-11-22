-- pgTAP: retrè klase/frè yo kalkile nan backend la; sèlman risk ka rete an atant.
begin;
select plan(12);

insert into auth.users(id, email) values
  ('00000000-0000-0000-0000-0000000000a2','admin-withdraw@test.local'),
  ('00000000-0000-0000-0000-0000000000b2','client-withdraw@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000a2';

insert into public.savings_plans(id, user_id, title, has_goal, goal_amount) values
  ('00000000-0000-0000-0000-0000000000c2','00000000-0000-0000-0000-0000000000b2','Plan fleksib',false,null),
  ('00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-0000000000b2','Objektif pa rive',true,10000),
  ('00000000-0000-0000-0000-0000000000c4','00000000-0000-0000-0000-0000000000b2','Objektif rive',true,10000);

insert into public.deposit_requests(id, plan_id, user_id, method, amount) values
  ('00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-0000000000c2','00000000-0000-0000-0000-0000000000b2','cash',5000),
  ('00000000-0000-0000-0000-0000000000d3','00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-0000000000b2','cash',4000),
  ('00000000-0000-0000-0000-0000000000d4','00000000-0000-0000-0000-0000000000c4','00000000-0000-0000-0000-0000000000b2','cash',12000);
insert into public.deposits(id, plan_id, user_id, deposit_request_id, amount, method, confirmed_by) values
  ('00000000-0000-0000-0000-0000000000e2','00000000-0000-0000-0000-0000000000c2','00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000d2',5000,'cash','00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000e3','00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000d3',4000,'cash','00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000e4','00000000-0000-0000-0000-0000000000c4','00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000d4',12000,'cash','00000000-0000-0000-0000-0000000000a2');

update public.app_settings set fees_enabled = true, normal_withdrawal_fee_percent = 1, emergency_withdrawal_fee_percent = 5 where id = 1;
update public.compliance_settings set kyc_threshold = 9000000, aml_review_amount = 9000000, aml_max_requests_24h = 50 where id = 1;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000b2',true);

select is(public.quote_withdrawal('00000000-0000-0000-0000-0000000000c2',500)->>'kind','normal','plan san objektif itilize frè nòmal');
select is((public.quote_withdrawal('00000000-0000-0000-0000-0000000000c2',500)->>'fee_percent')::numeric,1::numeric,'plan fleksib pran pousantaj nòmal');
select is(public.quote_withdrawal('00000000-0000-0000-0000-0000000000c3',500)->>'kind','emergency','plan objektif ki poko rive klase ijans');
select is((public.quote_withdrawal('00000000-0000-0000-0000-0000000000c3',500)->>'fee_percent')::numeric,5::numeric,'plan objektif ki poko rive pran pousantaj ijans');
select is(public.quote_withdrawal('00000000-0000-0000-0000-0000000000c4',500)->>'kind','normal','plan ki deja rive objektif la retounen nan frè nòmal');

select is((public.request_withdrawal(
  '00000000-0000-0000-0000-0000000000c2',500,'normal',null,null,'cash',1,
  '00000000-0000-0000-0000-0000000000f2'
)->>'status'),'approved','retrè ki pase kontwòl yo otorize otomatikman');
select is((public.request_withdrawal(
  '00000000-0000-0000-0000-0000000000c2',500,'normal',null,null,'cash',1,
  '00000000-0000-0000-0000-0000000000f2'
)->>'replayed'),'true','retry menm idempotency key pa kreye yon nouvo retrè');
select is((select count(*)::int from public.withdrawal_requests where idempotency_key='00000000-0000-0000-0000-0000000000f2'),1,'yon sèl demann egziste pou menm idempotency key la');

update public.compliance_settings set aml_review_amount = 100, aml_max_requests_24h = 50 where id = 1;
select is((public.quote_withdrawal('00000000-0000-0000-0000-0000000000c2',300)->>'manual_review'),'true','gwo montan resevwa drapo revizyon');
select is((public.request_withdrawal(
  '00000000-0000-0000-0000-0000000000c2',300,'normal',null,null,'cash',1,
  '00000000-0000-0000-0000-0000000000f3'
)->>'status'),'pending','demann ki gen drapo risk rete an atant');
select is((select authorization_mode from public.withdrawal_requests where idempotency_key='00000000-0000-0000-0000-0000000000f3'),'manual_review','demann risk make kòm revizyon manyèl');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a2',true);
select lives_ok($$select public.admin_review_withdrawal((select id from public.withdrawal_requests where idempotency_key='00000000-0000-0000-0000-0000000000f3'),'approved','Revizyon risk fini')$$,'admin kapab revize sèlman ka ki rete an atant');

select * from finish();
rollback;
