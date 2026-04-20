import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { buildPayload } from "$lib/server/search-indexer";
import type { RequestHandler } from "./$types";

export const POST: RequestHandler = async ({ request, locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const { source_type, source_id } = await request.json();
  if (!source_type || !source_id) {
    throw error(400, "source_type and source_id are required");
  }

  const admin = getAdminClient();
  const payload = await buildPayload(source_type, source_id, admin);
  if (!payload) {
    return json({ status: "skipped", reason: "record not found" });
  }

  const { error: upsertError } = await admin
    .from("search_documents")
    .upsert(payload, { onConflict: "source_type,source_id" });

  if (upsertError) {
    console.error("search_documents upsert error:", upsertError);
    throw error(502, "Indexing failed");
  }

  return json({ status: "indexed" });
};
