-- Pa gen done kliyan reyèl nan seed sa a.
-- Pou anviwònman dev sèlman, admin nan dwe kreye yon kont ak Supabase Auth,
-- verifye UUID a, epi bay role='admin' manyèlman jan README eksplike.
select id, normal_withdrawal_fee_percent, emergency_withdrawal_fee_percent, fees_enabled
from public.app_settings;
