import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import type { RequestHandler } from "./$types";

export const POST: RequestHandler = async ({ request, locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const { query, types, limit } = await request.json();
  if (!query || typeof query !== "string") {
    throw error(400, "query is required");
  }

  const userId = locals.session.user.id;
  const admin = getAdminClient();
  const { data: members } = await admin
    .from("organization_members")
    .select("organization_id")
    .eq("user_id", userId);

  const orgIds = (members ?? []).map((m) => m.organization_id);
  if (orgIds.length === 0) throw error(400, "User has no organization");

  const { data, error: rpcError } = await admin.rpc("universal_search", {
    query_text: query,
    filter_org_ids: orgIds,
    filter_types: Array.isArray(types) && types.length > 0 ? types : null,
    match_count: typeof limit === "number" && limit > 0 ? limit : 20,
  });

  if (rpcError) {
    console.error("universal_search error:", rpcError);
    throw error(502, "Search failed");
  }

  return json({ results: data ?? [] });
};
