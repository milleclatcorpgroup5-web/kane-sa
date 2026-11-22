begin;
select plan(27);

select has_table('public','money_rail_controls','tab verrou finansye egziste');
select has_table('public','money_provider_accounts','rejis provider egziste');
select has_table('public','payment_intents','tab entansyon peman egziste');
select has_table('public','payout_attempts','tab tantativ payout egziste');
select has_table('public','provider_webhook_inbox','inbox webhook egziste');
select has_table('public','provider_settlement_batches','tab deklarasyon provider egziste');
select has_table('public','provider_settlement_entries','liy deklarasyon provider egziste');
select has_table('public','provider_reconciliation_runs','tab run rekonsilyasyon provider egziste');
select has_table('public','provider_reconciliation_issues','tab eksepsyon rekonsilyasyon provider egziste');
select has_trigger('public','payment_intents','payment_intent_target_guard','intent la verifye demann depo/retrè orijinal la');
select has_trigger('public','payout_attempts','payout_attempt_target_guard','payout la verifye montan net ak estati approved');
select has_trigger('public','provider_settlement_entries','settlement_entry_provider_guard','liy statement la verifye provider batch li');
select has_trigger('public','provider_reconciliation_runs','provider_reconciliation_run_guard','run rekonsilyasyon an verifye provider batch li');
select has_trigger('public','provider_reconciliation_issues','provider_reconciliation_issue_guard','eksepsyon an dwe koresponn ak batch run li');
select has_trigger('public','money_rail_controls','money_rail_control_no_delete','verrou finansye a pa ka efase');
select is((select live_money_enabled from public.money_rail_controls where id=1), false, 'lajan reyèl rete dezaktive');
select is((select inbound_enabled from public.money_rail_controls where id=1), false, 'depo provider rete dezaktive');
select is((select outbound_enabled from public.money_rail_controls where id=1), false, 'payout provider rete dezaktive');
select is((select kill_switch from public.money_rail_controls where id=1), true, 'kill switch rete aktive');
select is((select count(*)::int from public.money_provider_accounts where enabled or environment <> 'disabled'), 0, 'tout provider rete dezaktive');
select ok(not has_table_privilege('authenticated','public.payment_intents','INSERT'), 'kliyan/admin pa gen dwa kreye payment intents dirèkteman');
select ok(not has_table_privilege('authenticated','public.payout_attempts','UPDATE'), 'wòl authenticated pa gen dwa modifye payout attempts');
select ok(not has_table_privilege('anon','public.provider_webhook_inbox','SELECT'), 'anon pa ka li inbox webhook');
select throws_ok($$update public.money_rail_controls set live_money_enabled = true where id=1$$,
  '23514', null, 'constraint bazdone anpeche aktive lajan reyèl');
select throws_ok($$update public.compliance_settings set live_mode = true where id=1$$,
  '23514', null, 'ansyen flag live_mode la pa ka aktive dirèkteman');

insert into auth.users(id,email) values
  ('00000000-0000-0000-0000-0000000008a1','money-admin@test.local'),
  ('00000000-0000-0000-0000-0000000008b1','money-client@test.local');
update public.profiles set role='admin' where id='00000000-0000-0000-0000-0000000008a1';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000008b1',true);
select is((select count(*)::int from public.money_provider_accounts), 0, 'kliyan pa ka li rejis provider admin-only');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000008a1',true);
select throws_ok($$select public.admin_set_live_mode(true)$$,
  'P0001', 'Mòd lajan reyèl la fèmen nan vèsyon sa a. Li mande yon nouvo migration, entegrasyon, odit ak apwobasyon separe.',
  'menm admin pa ka aktive mòd reyèl nan vèsyon sa a');

select * from finish();
rollback;
