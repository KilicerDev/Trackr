import { createClient, type SupabaseClient } from "@supabase/supabase-js";

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

let jwt = "";
let cachedUserId = "";
let exchangeInFlight: Promise<void> | null = null;

async function exchange(): Promise<void> {
  if (exchangeInFlight) return exchangeInFlight;
  const trackrUrl = required("TRACKR_URL");
  const apiKey = required("TRACKR_API_KEY");
  exchangeInFlight = (async () => {
    const res = await fetch(`${trackrUrl.replace(/\/$/, "")}/api/auth/exchange`, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`Auth exchange failed (${res.status}): ${body || res.statusText}`);
    }
    const data = (await res.json()) as { access_token: string; user_id: string };
    jwt = data.access_token;
    cachedUserId = data.user_id;
  })();
  try {
    await exchangeInFlight;
  } finally {
    exchangeInFlight = null;
  }
}

const fetchWithAuth: typeof fetch = async (input, init = {}) => {
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${jwt}`);
  let res = await fetch(input, { ...init, headers });
  if (res.status === 401) {
    await exchange();
    headers.set("Authorization", `Bearer ${jwt}`);
    res = await fetch(input, { ...init, headers });
  }
  return res;
};

export async function buildClient(): Promise<SupabaseClient> {
  const url = required("TRACKR_SUPABASE_URL");
  const anonKey = required("TRACKR_SUPABASE_ANON_KEY");
  required("TRACKR_URL");
  required("TRACKR_API_KEY");

  await exchange();

  return createClient(url, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: { fetch: fetchWithAuth },
  });
}

export async function currentUserId(): Promise<string> {
  if (!cachedUserId) {
    throw new Error("Not authenticated — call buildClient() first");
  }
  return cachedUserId;
}
