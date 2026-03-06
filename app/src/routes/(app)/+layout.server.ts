import { error, redirect } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ parent }) => {
  const { user, role } = await parent();
  if (!user) throw redirect(303, "/login");
  if (role?.role_slug === "client") throw error(403, "Unauthorized");
};