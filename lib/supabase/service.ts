import { createClient } from '@supabase/supabase-js';
import type { Database } from './database.types';

/** Sèlman sèvè a (rout API). Pa janm itilize nan kòd ki rive nan navigatè a. */
export function createServiceClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Service role pa konfigire.');
  return createClient<Database>(url, key, { auth: { persistSession: false } });
}
