import { fail } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import type { Actions } from "./$types";

export const actions: Actions = {
  default: async ({ request, url }) => {
    const formData = await request.formData();
    const email = formData.get("email") as string;

    if (!email) {
      return fail(400, { email, message: "Email is required" });
    }

    const redirectTo = `${url.origin}/auth/callback`;

    // Use admin client (implicit flow) instead of the SSR server client (PKCE).
    // PKCE stores a code_verifier cookie that is often lost by the time the user
    // clicks the email link, causing the code exchange to fail silently.
    // Implicit flow sends tokens directly in the URL hash, which is more reliable.
    const adminClient = getAdminClient();
    const { error } = await adminClient.auth.resetPasswordForEmail(email, {
      redirectTo,
    });

    if (error) {
      return fail(500, { email, message: error.message });
    }

    return { success: true, email };
  },
};
