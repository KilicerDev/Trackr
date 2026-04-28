import type { PageServerLoad } from "./$types";
import { isClientAreaRole } from "$lib/types/auth";

export const load: PageServerLoad = async ({ parent, locals }) => {
  if (!locals.user) {
    return { redirectTo: "/" };
  }

  const { role } = await parent();
  const redirectTo = isClientAreaRole(role) ? "/c" : "/";

  return { redirectTo };
};
