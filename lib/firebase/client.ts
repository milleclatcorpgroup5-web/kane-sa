'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import { getMessaging, isSupported } from 'firebase/messaging';

const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

export function getFirebaseApp() {
  if (!config.apiKey || !config.projectId || !config.appId) return null;
  return getApps().length ? getApp() : initializeApp(config);
}

export async function getFirebaseMessaging() {
  if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return null;
  const supported = await isSupported();
  const app = getFirebaseApp();
  return supported && app ? getMessaging(app) : null;
}
