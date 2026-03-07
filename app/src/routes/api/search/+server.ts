import { json, error } from "@sveltejs/kit";
import { env } from "$env/dynamic/private";
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

  const embedUrl = env.EMBED_SERVICE_URL;
  const embedToken = env.EMBED_SERVICE_TOKEN;
  if (!embedUrl || !embedToken) {
    throw error(503, "Search service not configured");
  }

  const res = await fetch(`${embedUrl}/search`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${embedToken}`,
    },
    body: JSON.stringify({
      query,
      org_ids: orgIds,
      types: types ?? null,
      limit: limit ?? 20,
    }),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    console.error("embed-service /search error:", res.status, text);
    throw error(502, "Search service error");
  }

  return json(await res.json());
};
