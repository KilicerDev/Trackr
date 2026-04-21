import { error, fail, redirect } from "@sveltejs/kit";
import type { PageServerLoad, Actions } from "./$types";

const ALLOWED_REDIRECT_ORIGINS = new Set([
  "https://claude.ai",
  "https://claude.com",
]);

function isAllowedRedirect(raw: string): boolean {
  try {
    const u = new URL(raw);
    return ALLOWED_REDIRECT_ORIGINS.has(u.origin);
  } catch {
    return false;
  }
}

export const load: PageServerLoad = async ({ url, locals, setHeaders }) => {
  setHeaders({
    "X-Frame-Options": "DENY",
    "Content-Security-Policy": "frame-ancestors 'none'",
    "Cache-Control": "no-store",
  });

  const authorizationId = url.searchParams.get("authorization_id");
  if (!authorizationId) throw error(400, "authorization_id required");

  if (!locals.user) {
    throw redirect(303, `/login?next=${encodeURIComponent(url.pathname + url.search)}`);
  }

  const { data, error: err } =
    await locals.supabase.auth.oauth.getAuthorizationDetails(authorizationId);
  if (err || !data) throw error(400, err?.message ?? "Unknown authorization");

  // Already consented — Supabase returns the redirect URL directly.
  if ("redirect_url" in data) {
    if (!isAllowedRedirect(data.redirect_url)) {
      throw error(400, "redirect_uri not permitted");
    }
    throw redirect(303, data.redirect_url);
  }

  if (!isAllowedRedirect(data.redirect_uri)) {
    throw error(400, "redirect_uri not permitted");
  }

  return {
    authorizationId,
    client: data.client,
    scope: data.scope,
    redirectUri: data.redirect_uri,
  };
};

export const actions: Actions = {
  approve: async ({ request, locals }) => {
    if (!locals.user) throw redirect(303, "/login");
    const form = await request.formData();
    const authorizationId = form.get("authorization_id");
    if (typeof authorizationId !== "string") return fail(400, { message: "missing authorization_id" });

    const { data, error: err } = await locals.supabase.auth.oauth.approveAuthorization(
      authorizationId,
      { skipBrowserRedirect: true }
    );
    if (err || !data) return fail(400, { message: err?.message ?? "approve failed" });
    if (!isAllowedRedirect(data.redirect_url)) return fail(400, { message: "redirect_uri not permitted" });
    throw redirect(303, data.redirect_url);
  },

  deny: async ({ request, locals }) => {
    if (!locals.user) throw redirect(303, "/login");
    const form = await request.formData();
    const authorizationId = form.get("authorization_id");
    if (typeof authorizationId !== "string") return fail(400, { message: "missing authorization_id" });

    const { data, error: err } = await locals.supabase.auth.oauth.denyAuthorization(
      authorizationId,
      { skipBrowserRedirect: true }
    );
    if (err || !data) return fail(400, { message: err?.message ?? "deny failed" });
    if (!isAllowedRedirect(data.redirect_url)) return fail(400, { message: "redirect_uri not permitted" });
    throw redirect(303, data.redirect_url);
  },
};
