import { createClient } from '@/lib/supabase/server';

export async function requireAdminApi() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { response: Response.json({ error: 'Ou dwe konekte.' }, { status: 401 }) };
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
  if (profile?.role !== 'admin') return { response: Response.json({ error: 'Aksè admin sèlman.' }, { status: 403 }) };
  return { supabase, user };
}
