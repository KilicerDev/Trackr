import { redirect } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";
import { isClientAreaRole } from "$lib/types/auth";

export const load: LayoutServerLoad = async ({ parent }) => {
  const { user, role } = await parent();
  if (!user) return;
  if (isClientAreaRole(role)) redirect(303, "/c");
  redirect(303, "/");
};
