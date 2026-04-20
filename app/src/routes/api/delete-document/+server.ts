import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import type { RequestHandler } from "./$types";

export const DELETE: RequestHandler = async ({ request, locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const { source_type, source_id } = await request.json();
  if (!source_type || !source_id) {
    throw error(400, "source_type and source_id are required");
  }

  const admin = getAdminClient();
  const { error: deleteError } = await admin
    .from("search_documents")
    .delete()
    .match({ source_type, source_id });

  if (deleteError) {
    console.error("search_documents delete error:", deleteError);
    throw error(502, "Delete failed");
  }

  return json({ status: "deleted" });
};
