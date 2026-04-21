import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import {
  generateAccessToken,
  hash,
  verifyPkce,
  rateLimit,
  ACCESS_TOKEN_TTL_SEC,
} from "$lib/server/oauth";

function invalidGrant(message: string): never {
  throw error(400, `invalid_grant: ${message}`);
}

export const POST: RequestHandler = async ({ request, getClientAddress, setHeaders }) => {
  setHeaders({ "Cache-Control": "no-store", Pragma: "no-cache" });

  const ip = getClientAddress();
  if (!rateLimit(`oauth.token:${ip}`, 60, 60 * 1000)) {
    throw error(429, "Rate limit exceeded");
  }

  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/x-www-form-urlencoded")) {
    throw error(400, "Content-Type must be application/x-www-form-urlencoded");
  }

  const body = new URLSearchParams(await request.text());
  const grantType = body.get("grant_type");
  if (grantType !== "authorization_code") {
    throw error(400, "unsupported_grant_type: only authorization_code is supported");
  }

  const code = body.get("code");
  const clientId = body.get("client_id");
  const redirectUri = body.get("redirect_uri");
  const codeVerifier = body.get("code_verifier");

  if (!code || !clientId || !redirectUri || !codeVerifier) {
    throw error(400, "invalid_request: missing parameters");
  }

  const admin = getAdminClient();
  const codeHash = await hash(code);

  const { data: row } = await admin
    .from("oauth_authorization_codes")
    .select("code_hash, client_id, user_id, redirect_uri, code_challenge, scope, resource, used_at, expires_at")
    .eq("code_hash", codeHash)
    .maybeSingle();

  if (!row) invalidGrant("unknown code");

  if (row.used_at) {
    // Replay — revoke any tokens already issued from this code (defense in depth).
    await admin
      .from("oauth_access_tokens")
      .update({ revoked_at: new Date().toISOString() })
      .eq("authz_code_hash", codeHash)
      .is("revoked_at", null);
    invalidGrant("code already used");
  }

  if (new Date(row.expires_at).getTime() < Date.now()) invalidGrant("code expired");

  if (row.client_id !== clientId) invalidGrant("client_id mismatch");
  if (row.redirect_uri !== redirectUri) invalidGrant("redirect_uri mismatch");

  if (!(await verifyPkce(codeVerifier, row.code_challenge))) {
    invalidGrant("PKCE verification failed");
  }

  // Mark code as used, then issue token.
  await admin
    .from("oauth_authorization_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("code_hash", codeHash);

  const accessToken = generateAccessToken();
  const tokenHash = await hash(accessToken);
  const expiresAt = new Date(Date.now() + ACCESS_TOKEN_TTL_SEC * 1000);

  const { error: insertErr } = await admin.from("oauth_access_tokens").insert({
    token_hash: tokenHash,
    client_id: row.client_id,
    user_id: row.user_id,
    authz_code_hash: codeHash,
    scope: row.scope,
    resource: row.resource,
    expires_at: expiresAt.toISOString(),
  });
  if (insertErr) throw error(500, "Failed to issue token");

  // Touch client last_used_at (fire and forget)
  admin
    .from("oauth_clients")
    .update({ last_used_at: new Date().toISOString() })
    .eq("client_id", row.client_id)
    .then(() => {});

  return json({
    access_token: accessToken,
    token_type: "Bearer",
    expires_in: ACCESS_TOKEN_TTL_SEC,
    scope: row.scope.join(" "),
  });
};
