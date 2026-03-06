import { redirect } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ parent }) => {
  const { user, role } = await parent();
  if (!user) return;
  if (role?.role_slug === "client") redirect(303, "/c");
  redirect(303, "/");
};
