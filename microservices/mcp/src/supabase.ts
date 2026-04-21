import { createClient, type SupabaseClient } from "@supabase/supabase-js";

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

export function buildClient(jwt: string): SupabaseClient {
  const url = required("SUPABASE_URL");
  const anonKey = required("SUPABASE_ANON_KEY");

  const fetchWithAuth: typeof fetch = (input, init = {}) => {
    const headers = new Headers(init.headers);
    headers.set("Authorization", `Bearer ${jwt}`);
    return fetch(input, { ...init, headers });
  };

  return createClient(url, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: { fetch: fetchWithAuth },
  });
}
