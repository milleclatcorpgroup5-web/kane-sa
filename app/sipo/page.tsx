import { Header } from '@/components/header';
import { SupportDesk, type SupportTicket } from '@/components/support-desk';
import { requireUser } from '@/lib/auth';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Sant sipò' };

export default async function SupportPage() {
  const { supabase, user } = await requireUser();
  const { data: ticketRows } = await supabase.from('support_tickets')
    .select('id,subject,category,status,priority,created_at,updated_at,last_message_at')
    .eq('user_id', user.id).order('last_message_at', { ascending: false }).limit(50);
  const ids = (ticketRows ?? []).map((ticket) => ticket.id);
  const { data: messageRows } = ids.length
    ? await supabase.from('support_ticket_messages').select('id,ticket_id,sender_id,body,created_at').in('ticket_id', ids).order('created_at')
    : { data: [] };
  const messages = messageRows ?? [];
  const tickets = (ticketRows ?? []).map((ticket) => ({
    ...ticket, messages: messages.filter((message) => message.ticket_id === ticket.id),
  })) as SupportTicket[];
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Asistans KANÈ SA</span><h1>Sant sipò</h1><p className="muted">Ouvri yon dosye epi swiv repons yo nan menm konvèsasyon an.</p></div></div><SupportDesk tickets={tickets} userId={user.id} /></main></>;
}
