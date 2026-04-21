import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { generateClientId, isAllowedRedirectUri, rateLimit } from "$lib/server/oauth";

/**
 * POST /oauth/register — Dynamic Client Registration (RFC 7591).
 *
 * Public clients only. We force `token_endpoint_auth_method = "none"` and the
 * authorization_code grant regardless of what the client submits. No secrets
 * are issued.
 */
export const POST: RequestHandler = async ({ request, getClientAddress }) => {
  const ip = getClientAddress();
  if (!rateLimit(`oauth.register:${ip}`, 10, 60 * 60 * 1000)) {
    throw error(429, "Rate limit exceeded");
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    throw error(400, "Invalid JSON body");
  }

  const redirectUris = body.redirect_uris;
  if (!Array.isArray(redirectUris) || redirectUris.length === 0 || redirectUris.length > 10) {
    throw error(400, "redirect_uris must be a non-empty array of at most 10 URIs");
  }
  const uris: string[] = [];
  for (const u of redirectUris) {
    if (typeof u !== "string" || !isAllowedRedirectUri(u)) {
      throw error(400, `redirect_uri not allowed: ${String(u).slice(0, 200)}`);
    }
    uris.push(u);
  }

  const rawName = typeof body.client_name === "string" ? body.client_name.trim() : "";
  if (!rawName) throw error(400, "client_name is required");
  if (rawName.length > 120) throw error(400, "client_name too long");

  const optionalStr = (k: string): string | null => {
    const v = body[k];
    if (v == null || v === "") return null;
    if (typeof v !== "string") throw error(400, `${k} must be a string`);
    if (v.length > 512) throw error(400, `${k} too long`);
    return v;
  };

  // logo_uri must be https if provided (displayed on consent page)
  const logoUri = optionalStr("logo_uri");
  if (logoUri && !/^https:\/\//.test(logoUri)) {
    throw error(400, "logo_uri must be https");
  }

  const clientId = generateClientId();
  const admin = getAdminClient();
  const { data, error: dbErr } = await admin
    .from("oauth_clients")
    .insert({
      client_id: clientId,
      client_name: rawName,
      redirect_uris: uris,
      logo_uri: logoUri,
      policy_uri: optionalStr("policy_uri"),
      tos_uri: optionalStr("tos_uri"),
      software_id: optionalStr("software_id"),
      software_version: optionalStr("software_version"),
    })
    .select("client_id, created_at, redirect_uris, grant_types, response_types, token_endpoint_auth_method, client_name")
    .single();

  if (dbErr || !data) throw error(500, "Failed to register client");

  return json(
    {
      client_id: data.client_id,
      client_id_issued_at: Math.floor(new Date(data.created_at).getTime() / 1000),
      client_name: data.client_name,
      redirect_uris: data.redirect_uris,
      grant_types: data.grant_types,
      response_types: data.response_types,
      token_endpoint_auth_method: data.token_endpoint_auth_method,
    },
    { status: 201 }
  );
};
