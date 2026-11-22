-- Apre ou fin kreye kont ou nan app la, chanje imel la ak pa ou epi egzekite yon sèl fwa nan SQL Editor Supabase.
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'IMEL_OU@exemple.com');
