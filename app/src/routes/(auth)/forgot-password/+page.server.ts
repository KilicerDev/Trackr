import { fail } from "@sveltejs/kit";
import type { Actions } from "./$types";

export const actions: Actions = {
  default: async ({ request, locals: { supabase }, url }) => {
    const formData = await request.formData();
    const email = formData.get("email") as string;

    if (!email) {
      return fail(400, { email, message: "Email is required" });
    }

    const redirectTo = `${url.origin}/auth/callback`;

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo,
    });

    if (error) {
      return fail(500, { email, message: error.message });
    }

    return { success: true, email };
  },
};
