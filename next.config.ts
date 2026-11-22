import type { NextConfig } from 'next';

// CSP an mòd Report-Only: gade konsòl navigatè a, epi pase l an "Content-Security-Policy" apre tès.
const csp = [
  "default-src 'self'", "base-uri 'self'", "form-action 'self'", "frame-ancestors 'none'",
  "img-src 'self' data: blob:", "style-src 'self' 'unsafe-inline'", "script-src 'self' 'unsafe-inline'", "font-src 'self' data:",
  "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://*.googleapis.com https://*.firebaseio.com",
].join('; ');

const nextConfig: NextConfig = {
  poweredByHeader: false,
  reactStrictMode: true,
  eslint: { ignoreDuringBuilds: false },
  async headers() {
    return [{ source: '/(.*)', headers: [
      { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
      { key: 'Content-Security-Policy-Report-Only', value: csp },
    ] }];
  },
};

export default nextConfig;
