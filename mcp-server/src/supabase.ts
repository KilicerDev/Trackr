import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createFileStorage } from "./storage.js";

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

export async function buildClient(): Promise<SupabaseClient> {
  const url = required("TRACKR_SUPABASE_URL");
  const anonKey = required("TRACKR_SUPABASE_ANON_KEY");
  const storage = createFileStorage();

  const client = createClient(url, anonKey, {
    auth: {
      storage,
      storageKey: "trackr-mcp-auth",
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });

  const { data: existing } = await client.auth.getSession();
  if (existing.session) return client;

  const bootstrap = process.env.TRACKR_REFRESH_TOKEN;
  if (!bootstrap) {
    throw new Error(
      "No saved session and TRACKR_REFRESH_TOKEN not set. " +
        "Grab the refresh_token from your browser's Local Storage " +
        "(key sb-<ref>-auth-token on the Trackr web UI) and set it once.",
    );
  }

  const { error } = await client.auth.refreshSession({
    refresh_token: bootstrap,
  });
  if (error) throw new Error(`Failed to exchange refresh token: ${error.message}`);

  return client;
}

export async function currentUserId(client: SupabaseClient): Promise<string> {
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new Error("Not authenticated");
  return data.user.id;
}
