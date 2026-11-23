import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

/**
 * Fail-closed admin gate. Database/Auth outages must never grant access
 * and must not leak Supabase/Postgres diagnostics to the caller.
 */
export async function requireAdminApi() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError) {
      return {
        response: NextResponse.json(
          { error: 'Nou pa kapab verifye sesyon an. Tanpri rekonekte.' },
          { status: 503, headers: { 'Cache-Control': 'no-store' } },
        ),
      };
    }

    if (!user) {
      return {
        response: NextResponse.json(
          { error: 'Ou dwe konekte.' },
          { status: 401, headers: { 'Cache-Control': 'no-store' } },
        ),
      };
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      return {
        response: NextResponse.json(
          { error: 'Nou pa kapab verifye otorizasyon admin lan. Eseye ankò pita.' },
          { status: 503, headers: { 'Cache-Control': 'no-store' } },
        ),
      };
    }

    if (profile?.role !== 'admin') {
      return {
        response: NextResponse.json(
          { error: 'Aksè admin sèlman.' },
          { status: 403, headers: { 'Cache-Control': 'no-store' } },
        ),
      };
    }

    return { supabase, user };
  } catch {
    return {
      response: NextResponse.json(
        { error: 'Sèvis verifikasyon admin lan pa disponib. Eseye ankò pita.' },
        { status: 503, headers: { 'Cache-Control': 'no-store' } },
      ),
    };
  }
}
