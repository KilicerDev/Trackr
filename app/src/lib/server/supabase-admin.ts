import { createClient } from "@supabase/supabase-js";
import { PUBLIC_SUPABASE_URL } from "$env/static/public";
import { env } from "$env/dynamic/private";

export function getAdminClient() {
  const url = env.SUPABASE_URL ?? PUBLIC_SUPABASE_URL;
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";

  return createClient(url, serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
