import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { sha256 } from "$lib/server/ical";
import { signSupabaseJwt } from "$lib/server/api-keys";
import type { RequestHandler } from "@sveltejs/kit";

/**
 * POST /api/auth/exchange
 *
 * Trades a bearer credential for a short-lived Supabase-compatible JWT.
 * Accepts two credential formats:
 *   - `trk_*` — user-minted API key (long-lived, managed by /profile?tab=apiKeys)
 *   - `mcp_at_*` — OAuth 2.1 access token from the /oauth/token endpoint
 *
 * The JWT is signed with JWT_SECRET (HS256) and carries `sub = user_id`, so
 * PostgREST accepts it for RLS. This endpoint has no session guard — the bearer
 * token IS the credential.
 */
export const POST: RequestHandler = async ({ request }) => {
  const header = request.headers.get("authorization") ?? "";
  const bearer = header.match(/^Bearer\s+(\S+)$/)?.[1];
  if (!bearer) throw error(401, "Missing or malformed bearer credential");

  let userId: string | null = null;
  const admin = getAdminClient();

  if (bearer.startsWith("trk_")) {
    if (!/^trk_[A-Za-z0-9_-]+$/.test(bearer)) {
      throw error(401, "Malformed API key");
    }
    const hash = await sha256(bearer);
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
    userId = key.user_id;
  } else if (bearer.startsWith("mcp_at_")) {
    const hash = await sha256(bearer);
    const { data: tok } = await admin
      .from("oauth_access_tokens")
      .select("token_hash, user_id, expires_at, revoked_at")
      .eq("token_hash", hash)
      .is("revoked_at", null)
      .maybeSingle();
    if (!tok) throw error(401, "Invalid or revoked OAuth token");
    if (new Date(tok.expires_at).getTime() < Date.now()) {
      throw error(401, "OAuth token expired");
    }
    admin
      .from("oauth_access_tokens")
      .update({ last_used_at: new Date().toISOString() })
      .eq("token_hash", hash)
      .then(() => {});
    userId = tok.user_id;
  } else {
    throw error(401, "Unsupported credential prefix");
  }

  const { token, expiresIn } = await signSupabaseJwt(userId);
  return json({
    access_token: token,
    user_id: userId,
    expires_in: expiresIn,
    token_type: "Bearer",
  });
};
