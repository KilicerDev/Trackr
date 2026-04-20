import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { sha256 } from "$lib/server/ical";
import { generateApiKeyPlaintext } from "$lib/server/api-keys";
import type { RequestHandler } from "@sveltejs/kit";

const ALLOWED_EXPIRIES = new Set([7, 30, 90, 365]);

/**
 * GET — List the current user's API keys (never returns plaintext or hash).
 */
export const GET: RequestHandler = async ({ locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const { data, error: queryError } = await locals.supabase
    .from("api_keys")
    .select("id, name, prefix, scopes, expires_at, last_used_at, created_at, revoked_at")
    .eq("user_id", locals.session.user.id)
    .order("created_at", { ascending: false });

  if (queryError) {
    console.error("Failed to list api keys:", queryError);
    throw error(500, "Failed to list keys");
  }

  return json({ keys: data ?? [] });
};

/**
 * POST — Create a new API key. Returns plaintext exactly once.
 * Body: { name: string, expires_in_days?: 7 | 30 | 90 | 365 | null }
 */
export const POST: RequestHandler = async ({ locals, request }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const body = (await request.json().catch(() => null)) as {
    name?: unknown;
    expires_in_days?: unknown;
  } | null;

  const name = typeof body?.name === "string" ? body.name.trim() : "";
  if (!name) throw error(400, "Name is required");
  if (name.length > 100) throw error(400, "Name too long");

  let expiresAt: string | null = null;
  if (body?.expires_in_days !== null && body?.expires_in_days !== undefined) {
    const days = Number(body.expires_in_days);
    if (!ALLOWED_EXPIRIES.has(days)) {
      throw error(400, "Invalid expires_in_days");
    }
    expiresAt = new Date(Date.now() + days * 86_400_000).toISOString();
  }

  const { plaintext, prefix } = generateApiKeyPlaintext();
  const hash = await sha256(plaintext);

  const admin = getAdminClient();
  const { data, error: insertError } = await admin
    .from("api_keys")
    .insert({
      user_id: locals.session.user.id,
      name,
      key_hash: hash,
      prefix,
      expires_at: expiresAt,
    })
    .select("id, name, prefix, scopes, expires_at, last_used_at, created_at, revoked_at")
    .single();

  if (insertError || !data) {
    console.error("Failed to create api key:", insertError);
    throw error(500, "Failed to create key");
  }

  return json({ key: data, plaintext });
};
