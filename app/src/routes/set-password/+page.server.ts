import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ parent, locals }) => {
  if (!locals.user) {
    return { redirectTo: "/" };
  }

  const { role } = await parent();
  const redirectTo = role?.role_slug === "client" ? "/c" : "/";

  return { redirectTo };
};
