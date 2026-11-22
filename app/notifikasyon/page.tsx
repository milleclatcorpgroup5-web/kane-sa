import { Header } from '@/components/header';
import { NotificationList } from '@/components/notification-list';
import { requireUser } from '@/lib/auth';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Notifikasyon' };

export default async function NotificationsPage() {
  const { supabase, user } = await requireUser();
  const { data } = await supabase.from('user_notifications').select('id,kind,title,body,href,created_at,read_at')
    .eq('user_id', user.id).order('created_at', { ascending: false }).limit(100);
  return <><Header signedIn /><main className="container page"><div className="section-title"><div><span className="eyebrow">Sant aktivite</span><h1>Notifikasyon</h1><p className="muted">Enfòmasyon sou depo, retrè ak lòt aktivite kont ou.</p></div><span className="pill">{(data ?? []).filter((item) => !item.read_at).length} nouvo</span></div><NotificationList items={data ?? []} /></main></>;
}
