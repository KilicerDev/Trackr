import { createBrowserClient } from "@supabase/ssr";
import {
  PUBLIC_SUPABASE_URL,
  PUBLIC_SUPABASE_ANON_KEY,
} from "$env/static/public";

let instance: ReturnType<typeof createBrowserClient> | null = null;

export function getClient() {
  if (!instance) {
    instance = createBrowserClient(
      PUBLIC_SUPABASE_URL,
      PUBLIC_SUPABASE_ANON_KEY
    );
  }
  return instance;
}