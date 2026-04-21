import { createClient, type SupabaseClient } from "@supabase/supabase-js";

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

export type SessionAuth = {
  jwt: string;
  userId: string;
  expiresAt: number;
};

export async function exchangeApiKey(apiKey: string): Promise<SessionAuth> {
  const trackrUrl = required("TRACKR_URL");
  const res = await fetch(`${trackrUrl.replace(/\/$/, "")}/api/auth/exchange`, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Auth exchange failed (${res.status}): ${body || res.statusText}`);
  }
  const data = (await res.json()) as {
    access_token: string;
    user_id: string;
    expires_in: number;
  };
  return {
    jwt: data.access_token,
    userId: data.user_id,
    expiresAt: Date.now() + Math.max(0, data.expires_in - 30) * 1000,
  };
}

export function buildClient(apiKey: string, initial: SessionAuth): SupabaseClient {
  const url = required("TRACKR_SUPABASE_URL");
  const anonKey = required("TRACKR_SUPABASE_ANON_KEY");
  let current = initial;

  const fetchWithAuth: typeof fetch = async (input, init = {}) => {
    if (Date.now() >= current.expiresAt) {
      current = await exchangeApiKey(apiKey);
    }
    const headers = new Headers(init.headers);
    headers.set("Authorization", `Bearer ${current.jwt}`);
    let res = await fetch(input, { ...init, headers });
    if (res.status === 401) {
      current = await exchangeApiKey(apiKey);
      headers.set("Authorization", `Bearer ${current.jwt}`);
      res = await fetch(input, { ...init, headers });
    }
    return res;
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
