import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import type { RequestHandler } from "@sveltejs/kit";

/**
 * DELETE — Revoke an API key (soft delete, preserves last_used_at audit trail).
 */
export const DELETE: RequestHandler = async ({ locals, params }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const id = params.id;
  if (!id) throw error(400, "Missing id");

  const admin = getAdminClient();

  const { data, error: updateError } = await admin
    .from("api_keys")
    .update({ revoked_at: new Date().toISOString() })
    .eq("id", id)
    .eq("user_id", locals.session.user.id)
    .is("revoked_at", null)
    .select("id")
    .maybeSingle();

  if (updateError) {
    console.error("Failed to revoke api key:", updateError);
    throw error(500, "Failed to revoke key");
  }
  if (!data) throw error(404, "Key not found");

  return json({ ok: true });
};
