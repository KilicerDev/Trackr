import { error, redirect } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";
import { isClientAreaRole } from "$lib/types/auth";

export const load: LayoutServerLoad = async ({ parent }) => {
  const { user, role } = await parent();
  if (!user) throw redirect(303, "/login");
  if (isClientAreaRole(role)) throw error(403, "Unauthorized");
};