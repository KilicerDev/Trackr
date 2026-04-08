import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { sha256 } from "$lib/server/ical";
import type { RequestHandler } from "@sveltejs/kit";

/**
 * GET — Check whether the current user has an active iCal token.
 */
export const GET: RequestHandler = async ({ locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const userId = locals.session.user.id;
  const supabase = locals.supabase;

  const { data } = await supabase
    .from("ical_tokens")
    .select("id, created_at, last_used_at")
    .eq("user_id", userId)
    .is("revoked_at", null)
    .maybeSingle();

  return json({
    exists: !!data,
    created_at: data?.created_at ?? null,
    last_used_at: data?.last_used_at ?? null,
  });
};

/**
 * POST — Generate (or regenerate) an iCal token.
 * Returns the plaintext token exactly once; it is never stored.
 */
export const POST: RequestHandler = async ({ locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const userId = locals.session.user.id;
  const admin = getAdminClient();

  // Generate cryptographically random token (122 bits of entropy)
  const plaintext = crypto.randomUUID();
  const hash = await sha256(plaintext);

  // Delete any existing token for this user (regenerate)
  await admin.from("ical_tokens").delete().eq("user_id", userId);

  // Insert new token
  const { error: insertError } = await admin.from("ical_tokens").insert({
    user_id: userId,
    token_hash: hash,
  });

  if (insertError) {
    console.error("Failed to create iCal token:", insertError);
    throw error(500, "Failed to generate token");
  }

  return json({ token: plaintext });
};

/**
 * DELETE — Revoke the current user's iCal token.
 */
export const DELETE: RequestHandler = async ({ locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const userId = locals.session.user.id;
  const admin = getAdminClient();

  await admin.from("ical_tokens").delete().eq("user_id", userId);

  return json({ ok: true });
};
