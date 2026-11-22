import type { createClient } from '@/lib/supabase/server';
import { sendPush } from './fcm';

type Client = Awaited<ReturnType<typeof createClient>>;

/** Best-effort: yon erè notifikasyon pa janm dwe anpeche aksyon admin lan. */
export async function notifyRequest(supabase: Client, table: 'deposit_requests' | 'withdrawal_requests', id: string, title: string, body: string) {
  try {
    const { data } = table === 'deposit_requests'
      ? await supabase.from('deposit_requests').select('user_id').eq('id', id).maybeSingle()
      : await supabase.from('withdrawal_requests').select('user_id').eq('id', id).maybeSingle();
    if (data) await sendPush(data.user_id, title, body);
  } catch { /* ignore */ }
}
