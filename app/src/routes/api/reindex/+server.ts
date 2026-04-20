import { json, error } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { getPlatformOrgId, isSetupComplete } from "$lib/server/setup-check";
import { reindexOrganization } from "$lib/server/search-indexer";
import type { RequestHandler } from "./$types";

export const POST: RequestHandler = async ({ request, locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const admin = getAdminClient();
  const userId = locals.session.user.id;

  await isSetupComplete();
  const platformOrgId = getPlatformOrgId();

  let isPlatformMember = false;
  if (platformOrgId) {
    const { count } = await admin
      .from("organization_members")
      .select("*", { count: "exact", head: true })
      .eq("organization_id", platformOrgId)
      .eq("user_id", userId);
    isPlatformMember = (count ?? 0) > 0;
  }

  const { organization_id } = await request.json();
  if (!organization_id || typeof organization_id !== "string") {
    throw error(400, "organization_id is required");
  }

  const { data: roleRows } = await admin.rpc("get_user_role", {
    _user_id: userId,
    _organization_id: organization_id,
  });
  const roleSlug = (roleRows?.[0]?.role_slug as string | undefined) ?? null;

  if (!isPlatformMember && roleSlug !== "owner" && roleSlug !== "admin") {
    throw error(403, "Admin access required");
  }

  try {
    const counts = await reindexOrganization(organization_id, admin);
    return json({ status: "ok", counts });
  } catch (e) {
    console.error("reindex error:", e);
    throw error(500, e instanceof Error ? e.message : "Reindex failed");
  }
};
