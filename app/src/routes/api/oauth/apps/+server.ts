import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "@sveltejs/kit";

/**
 * GET /api/oauth/apps — list the OAuth clients the current user has granted
 * access to, along with whether they have any active access tokens.
 */
export const GET: RequestHandler = async ({ locals }) => {
  if (!locals.user) throw error(401, "Unauthorized");

  const { data, error: dbErr } = await locals.supabase
    .from("oauth_consents")
    .select(
      "client_id, scope, approved_at, oauth_clients!inner(client_id, client_name, logo_uri, last_used_at)"
    )
    .eq("user_id", locals.user.id);
  if (dbErr) throw error(500, dbErr.message);

  const rows = (data ?? []).map((row) => {
    const client = Array.isArray(row.oauth_clients) ? row.oauth_clients[0] : row.oauth_clients;
    return {
      client_id: row.client_id,
      scope: row.scope,
      approved_at: row.approved_at,
      client_name: client?.client_name ?? row.client_id,
      logo_uri: client?.logo_uri ?? null,
      last_used_at: client?.last_used_at ?? null,
    };
  });

  return json({ apps: rows });
};
