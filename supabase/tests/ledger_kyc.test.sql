-- pgTAP: egzekite ak `supabase test db`. Chema reyèl 0001 ka mande ajiste kèk kolòn obligatwa.
begin;
select plan(7);

insert into auth.users(id, email) values ('00000000-0000-0000-0000-0000000000a1','admin@test.local'), ('00000000-0000-0000-0000-0000000000b1','user@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.savings_plans(id, user_id, title) values ('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1','Plan tès');
insert into public.deposit_requests(id, plan_id, user_id, method, amount) values ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1','cash',50000);
insert into public.deposits(id, plan_id, user_id, deposit_request_id, amount, method, confirmed_by)
values ('00000000-0000-0000-0000-0000000000e1','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000d1',50000,'cash','00000000-0000-0000-0000-0000000000a1');

select is((select count(*)::int from public.ledger_entries where ref_id = '00000000-0000-0000-0000-0000000000e1'), 2, 'depo konfime poste 2 antre nan ledger');
select is((select sum(debit) - sum(credit) from public.ledger_entries), 0::numeric, 'ledger balanse');
select throws_ok($$update public.ledger_entries set debit = debit + 1$$, null, null, 'ledger se append-only');
select throws_ok($$insert into public.withdrawal_requests(plan_id,user_id,kind,gross_amount,fee_percent,fee_amount,net_amount) values ('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1','normal',30000,0,0,30000)$$, null, null, 'retrè > limit KYC bloke san KYC');

insert into public.kyc_profiles(user_id, legal_name, date_of_birth, address, document_type, document_last4, status) values ('00000000-0000-0000-0000-0000000000b1','Tès Itilizatè','1990-01-01','Pòtoprens, Ayiti','cin','1234','verified');
select lives_ok($$insert into public.withdrawal_requests(id,plan_id,user_id,kind,gross_amount,fee_percent,fee_amount,net_amount) values ('00000000-0000-0000-0000-0000000000f1','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1','normal',30000,0,0,30000)$$, 'retrè pase apre KYC verifye');
select is((select count(*)::int from public.aml_flags where user_id = '00000000-0000-0000-0000-0000000000b1'), 0, 'pa gen alèt AML anba limit');
update public.withdrawal_requests set status = 'paid', paid_by = '00000000-0000-0000-0000-0000000000a1', paid_at = now(), payment_method = 'cash', payment_reference = 'T1' where id = '00000000-0000-0000-0000-0000000000f1';
select is((select sum(credit - debit) from public.ledger_entries where account = 'customer_liability'), 20000::numeric, 'responsablite kliyan = depo - retrè peye');

select * from finish();
rollback;
