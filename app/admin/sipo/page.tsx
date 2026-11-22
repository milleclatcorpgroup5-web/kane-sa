import Link from 'next/link';
import { Header } from '@/components/header';
import { AdminSupportManager, type AdminSupportTicket } from '@/components/support-desk';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Jesyon sipò' };

export default async function AdminSupportPage() {
  const { supabase } = await requireRole(['admin']);
  const { data: ticketRows } = await supabase.from('support_tickets')
    .select('id,user_id,subject,category,status,priority,created_at,updated_at,last_message_at')
    .order('last_message_at', { ascending: false }).limit(100);
  const ids = (ticketRows ?? []).map((ticket) => ticket.id);
  const userIds = [...new Set((ticketRows ?? []).map((ticket) => ticket.user_id))];
  const [messageResult, profileResult] = await Promise.all([
    ids.length ? supabase.from('support_ticket_messages').select('id,ticket_id,sender_id,body,created_at').in('ticket_id', ids).order('created_at') : Promise.resolve({ data: [] as Array<{ id: string; ticket_id: string; sender_id: string; body: string; created_at: string }> }),
    userIds.length ? supabase.from('profiles').select('id,full_name,phone').in('id', userIds) : Promise.resolve({ data: [] as Array<{ id: string; full_name: string; phone: string | null }> }),
  ]);
  const messageRows = messageResult.data;
  const profiles = profileResult.data;
  const messages = messageRows ?? [];
  const profileMap = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
  const tickets = (ticketRows ?? []).map((ticket) => ({
    ...ticket,
    user_name: profileMap.get(ticket.user_id)?.full_name ?? ticket.user_id.slice(0, 8),
    user_phone: profileMap.get(ticket.user_id)?.phone ?? null,
    messages: messages.filter((message) => message.ticket_id === ticket.id),
  })) as AdminSupportTicket[];
  const openCount = tickets.filter((ticket) => !['resolved', 'closed'].includes(ticket.status)).length;
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Global Control</span><h1>Sipò kliyan</h1><p className="muted">Swiv dosye yo, reponn kliyan epi mete estati a ajou.</p></div><div className="actions"><span className="pill">{openCount} dosye ouvè</span><Link href="/admin">← Admin</Link></div></div><div className="notice notice-warning">Tout repons ki ekri isit la vizib pou kliyan an. Pa mete nòt entèn, modpas, PIN oswa done sansib nan repons yo.</div><AdminSupportManager tickets={tickets} /></main></>;
}
