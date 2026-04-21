import { redirect, error, fail } from "@sveltejs/kit";
import type { PageServerLoad, Actions } from "./$types";
import { getAdminClient } from "$lib/server/supabase-admin";
import {
  generateAuthorizationCode,
  hash,
  mcpResourceUrl,
  redirectUriMatches,
  CODE_TTL_SEC,
  SUPPORTED_SCOPES,
} from "$lib/server/oauth";

/**
 * GET /oauth/authorize — validates the request, ensures the user is logged in,
 * and either jumps straight to code issuance (pre-consented) or renders the
 * consent page.
 *
 * POST action "approve" / "deny" — mints the authorization code and redirects.
 */

type AuthorizeParams = {
  clientId: string;
  redirectUri: string;
  codeChallenge: string;
  codeChallengeMethod: "S256";
  state: string | null;
  scope: string[];
  resource: string | null;
};

type ParamSource = { get: (name: string) => string | null };

function parseParams(
  source: ParamSource,
  opts: { requireResponseType: boolean } = { requireResponseType: true }
): AuthorizeParams {
  if (opts.requireResponseType) {
    const responseType = source.get("response_type");
    if (responseType !== "code") throw error(400, "response_type must be 'code'");
  }

  const clientId = source.get("client_id");
  if (!clientId) throw error(400, "client_id required");

  const redirectUri = source.get("redirect_uri");
  if (!redirectUri) throw error(400, "redirect_uri required");

  const codeChallenge = source.get("code_challenge");
  if (!codeChallenge || codeChallenge.length < 43 || codeChallenge.length > 128) {
    throw error(400, "code_challenge required (43-128 chars)");
  }

  const method = source.get("code_challenge_method");
  if (method !== "S256") throw error(400, "code_challenge_method must be 'S256'");

  const scopeRaw = source.get("scope") ?? "mcp";
  const scope = scopeRaw.split(/\s+/).filter(Boolean);
  for (const s of scope) {
    if (!(SUPPORTED_SCOPES as readonly string[]).includes(s)) {
      throw error(400, `unsupported scope: ${s}`);
    }
  }

  const resource = source.get("resource");
  if (resource) {
    // Accept any URL whose origin matches the MCP server's origin — Claude.ai
    // and other clients may or may not include the /mcp path suffix.
    try {
      const mcpOrigin = new URL(mcpResourceUrl()).origin;
      const requested = new URL(resource).origin;
      if (requested !== mcpOrigin) {
        throw error(400, "resource does not match this MCP server");
      }
    } catch {
      throw error(400, "malformed resource parameter");
    }
  }

  return {
    clientId,
    redirectUri,
    codeChallenge,
    codeChallengeMethod: "S256",
    state: source.get("state"),
    scope,
    resource,
  };
}

const formParamSource = (form: FormData): ParamSource => ({
  get: (name) => {
    const v = form.get(name);
    return typeof v === "string" ? v : null;
  },
});

const urlParamSource = (url: URL): ParamSource => ({
  get: (name) => url.searchParams.get(name),
});

export const load: PageServerLoad = async ({ url, locals, cookies, setHeaders }) => {
  setHeaders({
    "X-Frame-Options": "DENY",
    "Content-Security-Policy": "frame-ancestors 'none'",
    "Cache-Control": "no-store",
  });

  const params = parseParams(urlParamSource(url));
  const admin = getAdminClient();

  const { data: client } = await admin
    .from("oauth_clients")
    .select(
      "client_id, client_name, redirect_uris, logo_uri, policy_uri, tos_uri, revoked_at"
    )
    .eq("client_id", params.clientId)
    .maybeSingle();

  if (!client || client.revoked_at) {
    throw error(400, "Unknown or revoked client");
  }

  if (!redirectUriMatches(params.redirectUri, client.redirect_uris)) {
    throw error(400, "redirect_uri does not match a registered URI");
  }

  if (!locals.user) {
    const next = url.pathname + url.search;
    throw redirect(303, `/login?next=${encodeURIComponent(next)}`);
  }

  // Anti-CSRF token bound to session cookie.
  let csrf = cookies.get("oauth_csrf");
  if (!csrf) {
    csrf = crypto.randomUUID();
    cookies.set("oauth_csrf", csrf, {
      path: "/oauth",
      httpOnly: true,
      sameSite: "lax",
      secure: url.protocol === "https:",
      maxAge: 10 * 60,
    });
  }

  // Pre-consented fast-path.
  const { data: existingConsent } = await admin
    .from("oauth_consents")
    .select("scope")
    .eq("user_id", locals.user.id)
    .eq("client_id", params.clientId)
    .maybeSingle();

  const alreadyConsented =
    existingConsent && params.scope.every((s) => existingConsent.scope.includes(s));

  return {
    params,
    client: {
      client_id: client.client_id,
      client_name: client.client_name,
      logo_uri: client.logo_uri,
      policy_uri: client.policy_uri,
      tos_uri: client.tos_uri,
    },
    csrf,
    alreadyConsented,
  };
};

async function issueCode(params: AuthorizeParams, userId: string): Promise<string> {
  const code = generateAuthorizationCode();
  const codeHash = await hash(code);
  const admin = getAdminClient();

  const { error: dbErr } = await admin.from("oauth_authorization_codes").insert({
    code_hash: codeHash,
    client_id: params.clientId,
    user_id: userId,
    redirect_uri: params.redirectUri,
    code_challenge: params.codeChallenge,
    code_challenge_method: params.codeChallengeMethod,
    scope: params.scope,
    resource: params.resource,
    expires_at: new Date(Date.now() + CODE_TTL_SEC * 1000).toISOString(),
  });

  if (dbErr) throw error(500, "Failed to issue authorization code");
  return code;
}

function appendQuery(uri: string, pairs: Record<string, string>): string {
  const u = new URL(uri);
  for (const [k, v] of Object.entries(pairs)) u.searchParams.set(k, v);
  return u.toString();
}

export const actions: Actions = {
  approve: async ({ request, locals, cookies }) => {
    if (!locals.user) throw redirect(303, "/login");

    const form = await request.formData();
    const csrfForm = form.get("csrf");
    const csrfCookie = cookies.get("oauth_csrf");
    if (!csrfForm || !csrfCookie || csrfForm !== csrfCookie) {
      return fail(403, { message: "CSRF check failed" });
    }

    const params = parseParams(formParamSource(form), { requireResponseType: false });
    const admin = getAdminClient();

    const { data: client } = await admin
      .from("oauth_clients")
      .select("client_id, redirect_uris, revoked_at")
      .eq("client_id", params.clientId)
      .maybeSingle();
    if (!client || client.revoked_at) return fail(400, { message: "Unknown client" });
    if (!redirectUriMatches(params.redirectUri, client.redirect_uris)) {
      return fail(400, { message: "redirect_uri mismatch" });
    }

    await admin
      .from("oauth_consents")
      .upsert(
        { user_id: locals.user.id, client_id: params.clientId, scope: params.scope },
        { onConflict: "user_id,client_id" }
      );

    const code = await issueCode(params, locals.user.id);
    const redirectTo = appendQuery(params.redirectUri, {
      code,
      ...(params.state ? { state: params.state } : {}),
    });

    cookies.delete("oauth_csrf", { path: "/oauth" });
    throw redirect(303, redirectTo);
  },

  deny: async ({ request, cookies }) => {
    const form = await request.formData();
    const params = parseParams(formParamSource(form), { requireResponseType: false });
    cookies.delete("oauth_csrf", { path: "/oauth" });
    const redirectTo = appendQuery(params.redirectUri, {
      error: "access_denied",
      ...(params.state ? { state: params.state } : {}),
    });
    throw redirect(303, redirectTo);
  },
};
