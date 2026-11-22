'use client';

import { getToken } from 'firebase/messaging';
import { getFirebaseMessaging } from './client';

export async function enablePushNotifications(): Promise<string> {
  const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
  if (!vapidKey) throw new Error('Firebase VAPID key la poko konfigire.');
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') throw new Error('Ou pa bay pèmisyon pou notifikasyon.');
  const messaging = await getFirebaseMessaging();
  if (!messaging) throw new Error('Navigatè sa a pa sipòte notifikasyon push.');
  const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js');
  const token = await getToken(messaging, { vapidKey, serviceWorkerRegistration: registration });
  if (!token) throw new Error('Nou pa rive jwenn token notifikasyon an.');
  // Token an dwe voye nan yon API prive pou estoke li. Pa janm mete token pèsonèl nan logs piblik.
  return token;
}
