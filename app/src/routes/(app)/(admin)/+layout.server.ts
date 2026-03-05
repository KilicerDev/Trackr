import { error } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ parent }) => {
  const { role, isPlatformMember } = await parent();
  const slug = role?.role_slug;

  if (!isPlatformMember && slug !== "owner" && slug !== "admin") {
    throw error(403, "You do not have permission to access this page.");
  }
};
