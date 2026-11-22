import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import type { Database } from './database.types';

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return response;

  const supabase = createServerClient<Database>(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });
  const protectedPath = ['/tableau-de-bord', '/kontwol', '/resi', '/kyc', '/plans', '/depots', '/retraits', '/historique', '/admin', '/kanesa'];
  let userExists = false;
  let authUserId: string | null = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    userExists = Boolean(user);
    authUserId = user?.id ?? null;
  } catch {
    // Supabase Auth outages must not crash public pages. Protected pages fail closed below.
  }

  if (protectedPath.some((path) => request.nextUrl.pathname.startsWith(path)) && !userExists) {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = '/connexion';
    redirectUrl.searchParams.set('next', request.nextUrl.pathname);
    return NextResponse.redirect(redirectUrl);
  }

  // Maintenance mode is a server-side write gate. Admins retain access for repair.
  // Keep logout available so a user can always leave their session.
  const mutatingMethod = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method.toUpperCase());
  const isLogout = request.nextUrl.pathname === '/api/auth/logout';
  if (userExists && authUserId && mutatingMethod && !isLogout) {
    try {
      const [{ data: profile, error: profileError }, { data: settings, error: settingsError }] = await Promise.all([
        supabase.from('profiles').select('role').eq('id', authUserId).maybeSingle(),
        supabase.from('app_settings').select('maintenance_mode').eq('id', 1).maybeSingle(),
      ]);
      if (profileError || settingsError || (settings?.maintenance_mode === true && profile?.role !== 'admin')) {
        const blocked = NextResponse.json(
          { error: settingsError || profileError
            ? 'Nou pa kapab verifye eta sistèm nan. Tanpri eseye ankò pita.'
            : 'KANÈ SA an mòd antretyen. Aksyon ki modifye done yo tanporèman bloke; konsiltasyon ak dekoneksyon rete disponib.' },
          { status: 503, headers: { 'Cache-Control': 'no-store', 'Retry-After': '300' } },
        );
        response.cookies.getAll().forEach(({ name, value, ...options }) => blocked.cookies.set(name, value, options));
        return blocked;
      }
    } catch {
      // Fail closed on mutation requests if the maintenance gate cannot be checked.
      const blocked = NextResponse.json(
        { error: 'Nou pa kapab verifye eta sistèm nan. Tanpri eseye ankò pita.' },
        { status: 503, headers: { 'Cache-Control': 'no-store', 'Retry-After': '300' } },
      );
      response.cookies.getAll().forEach(({ name, value, ...options }) => blocked.cookies.set(name, value, options));
      return blocked;
    }
  }
  return response;
}
