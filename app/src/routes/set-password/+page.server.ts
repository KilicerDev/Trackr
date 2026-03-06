import { redirect } from "@sveltejs/kit";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ parent, locals }) => {
  if (!locals.user) {
    throw redirect(303, "/login");
  }

  const { role } = await parent();
  const redirectTo = role?.role_slug === "client" ? "/c" : "/";

  return { redirectTo };
};
