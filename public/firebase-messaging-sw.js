/* Opsyonèl: ranplase valè yo ak Firebase web config ou anvan ou aktive FCM.
   Pa janm mete Firebase Admin private key oswa service-account JSON nan fichye sa a. */
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'YOUR_FIREBASE_API_KEY',
  authDomain: 'YOUR_PROJECT.firebaseapp.com',
  projectId: 'YOUR_PROJECT_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  appId: 'YOUR_FIREBASE_APP_ID'
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'KANÈ SA';
  self.registration.showNotification(title, {
    body: payload.notification?.body || 'Ou gen yon nouvo notifikasyon.',
    icon: '/icon-192.png'
  });
});
