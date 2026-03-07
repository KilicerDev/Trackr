import { json, error } from "@sveltejs/kit";
import { env } from "$env/dynamic/private";
import type { RequestHandler } from "./$types";

export const DELETE: RequestHandler = async ({ request, locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const { source_type, source_id } = await request.json();
  if (!source_type || !source_id) {
    throw error(400, "source_type and source_id are required");
  }

  const embedUrl = env.EMBED_SERVICE_URL;
  const embedToken = env.EMBED_SERVICE_TOKEN;
  if (!embedUrl || !embedToken) {
    throw error(503, "Search service not configured");
  }

  const res = await fetch(
    `${embedUrl}/index/${encodeURIComponent(source_type)}/${encodeURIComponent(source_id)}`,
    {
      method: "DELETE",
      headers: { Authorization: `Bearer ${embedToken}` },
    }
  );

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    console.error("embed-service delete error:", res.status, text);
    throw error(502, "Delete failed");
  }

  return json({ status: "deleted" });
};
