import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";

/**
 * DELETE /api/oauth/apps/:clientId — revoke the user's grant to a client.
 * Deletes the consent row AND marks every active access token for
 * (user, client) as revoked.
 */
export const DELETE: RequestHandler = async ({ locals, params }) => {
  if (!locals.user) throw error(401, "Unauthorized");
  const clientId = params.clientId;
  if (!clientId) throw error(400, "clientId required");

  const admin = getAdminClient();
  const now = new Date().toISOString();

  await admin
    .from("oauth_access_tokens")
    .update({ revoked_at: now })
    .eq("user_id", locals.user.id)
    .eq("client_id", clientId)
    .is("revoked_at", null);

  await admin
    .from("oauth_consents")
    .delete()
    .eq("user_id", locals.user.id)
    .eq("client_id", clientId);

  return json({ ok: true });
};
