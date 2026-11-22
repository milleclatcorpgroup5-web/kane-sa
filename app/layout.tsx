import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import './globals.css';
import { Splash } from '@/components/splash';

export const metadata: Metadata = {
  title: { default: 'KANÈ SA — Ekonomi pèsonèl ou', template: '%s | KANÈ SA' },
  description: 'Yon espas dijital pou òganize ekonomi pèsonèl ou ak plis transparans.',
  applicationName: 'KANÈ SA',
  manifest: '/manifest.webmanifest',
  robots: { index: false, follow: false },
};

export const viewport: Viewport = { themeColor: '#12304a', width: 'device-width', initialScale: 1 };

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return <html lang="ht"><body><Splash />{children}</body></html>;
}
