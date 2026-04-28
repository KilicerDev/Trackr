import { fail, redirect } from "@sveltejs/kit";
import type { Actions } from "./$types";

export const actions: Actions = {
  default: async ({ request, locals: { supabase } }) => {
    const formData = await request.formData();
    const email = formData.get("email") as string;
    const password = formData.get("password") as string;

    if (!email || !password) {
      return fail(400, { email, message: "Email and password are required" });
    }

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return fail(401, { email, message: error.message });
    }

    let redirectTo = "/";

    try {
      const user = data.user;
      if (user) {
        const { data: profile } = await supabase
          .from("users")
          .select("organization_id")
          .eq("id", user.id)
          .single();

        if (profile?.organization_id) {
          const { data: roles } = await supabase.rpc("get_user_role", {
            _user_id: user.id,
            _organization_id: profile.organization_id,
          });

          const r = roles?.[0];
          if (r && (r.role_slug === "client" || r.is_system === false)) {
            redirectTo = "/c";
          }
        }
      }
    } catch {
      // Role check failed — fall through to default redirect
    }

    redirect(303, redirectTo);
  },
};
