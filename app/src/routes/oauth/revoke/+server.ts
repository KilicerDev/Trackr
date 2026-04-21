import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { hash, rateLimit } from "$lib/server/oauth";

/**
 * POST /oauth/revoke — RFC 7009 token revocation.
 * Always returns 200; never leaks whether the token existed.
 */
export const POST: RequestHandler = async ({ request, getClientAddress, setHeaders }) => {
  setHeaders({ "Cache-Control": "no-store" });

  const ip = getClientAddress();
  if (!rateLimit(`oauth.revoke:${ip}`, 30, 60 * 1000)) {
    throw error(429, "Rate limit exceeded");
  }

  const contentType = request.headers.get("content-type") ?? "";
  let token: string | null = null;

  if (contentType.includes("application/x-www-form-urlencoded")) {
    const body = new URLSearchParams(await request.text());
    token = body.get("token");
  } else if (contentType.includes("application/json")) {
    try {
      const body = (await request.json()) as { token?: unknown };
      token = typeof body.token === "string" ? body.token : null;
    } catch {
      /* fall through */
    }
  }

  if (token) {
    const admin = getAdminClient();
    const h = await hash(token);
    await admin
      .from("oauth_access_tokens")
      .update({ revoked_at: new Date().toISOString() })
      .eq("token_hash", h)
      .is("revoked_at", null);
  }

  return json({}, { status: 200 });
};
