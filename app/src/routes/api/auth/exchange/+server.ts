import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { sha256 } from "$lib/server/ical";
import { signSupabaseJwt } from "$lib/server/api-keys";
import type { RequestHandler } from "@sveltejs/kit";

/**
 * POST /api/auth/exchange
 *
 * Trades a plaintext API key (sent as `Authorization: Bearer trk_...`) for a
 * short-lived Supabase-compatible JWT. The JWT is signed with JWT_SECRET
 * (HS256) and carries `sub = user_id`, so PostgREST accepts it for RLS.
 *
 * This endpoint has no session guard — the bearer token IS the credential.
 */
export const POST: RequestHandler = async ({ request }) => {
  const header = request.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(trk_[A-Za-z0-9_-]+)$/);
  if (!match) throw error(401, "Missing or malformed API key");

  const plaintext = match[1];
  const hash = await sha256(plaintext);

  const admin = getAdminClient();

  const { data: key } = await admin
    .from("api_keys")
    .select("id, user_id, expires_at, revoked_at")
    .eq("key_hash", hash)
    .is("revoked_at", null)
    .maybeSingle();

  if (!key) throw error(401, "Invalid or revoked API key");

  if (key.expires_at && new Date(key.expires_at).getTime() < Date.now()) {
    throw error(401, "API key expired");
  }

  admin
    .from("api_keys")
    .update({ last_used_at: new Date().toISOString() })
    .eq("id", key.id)
    .then(() => {});

  const { token, expiresIn } = await signSupabaseJwt(key.user_id);

  return json({
    access_token: token,
    user_id: key.user_id,
    expires_in: expiresIn,
    token_type: "Bearer",
  });
};
