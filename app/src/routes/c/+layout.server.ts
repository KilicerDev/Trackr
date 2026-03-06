import { error, redirect } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({
  parent,
  locals: { supabase },
}) => {
  const { user, role } = await parent();

  if (!user) throw redirect(303, "/login");
  if (role?.role_slug !== "client") throw error(403, "Unauthorized");

  const { data: memberships } = await supabase
    .from("organization_members")
    .select(
      "organization:organizations(id, name, slug, logo_url)"
    )
    .eq("user_id", user.id);

  const organizations = (memberships ?? [])
    .map((m) => m.organization as { id: string; name: string; slug: string; logo_url: string | null } | null)
    .filter((o): o is NonNullable<typeof o> => o !== null);

  return { organizations };
};
