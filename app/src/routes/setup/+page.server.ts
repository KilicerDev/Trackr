import { fail, redirect } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import { getAdminClient } from "$lib/server/supabase-admin";
import { invalidateSetupCache } from "$lib/server/setup-check";

function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export const load: PageServerLoad = async () => {
  const admin = getAdminClient();

  const { data: config } = await admin
    .from("system_config")
    .select("platform_organization_id")
    .limit(1)
    .single();

  if (config?.platform_organization_id) {
    redirect(303, "/login");
  }
};

export const actions: Actions = {
  default: async ({ request, locals: { supabase } }) => {
    const admin = getAdminClient();

    const { data: config } = await admin
      .from("system_config")
      .select("id, platform_organization_id")
      .limit(1)
      .single();

    if (config?.platform_organization_id) {
      redirect(303, "/login");
    }

    const formData = await request.formData();
    const orgName = (formData.get("org_name") as string)?.trim();
    const fullName = (formData.get("full_name") as string)?.trim();
    const email = (formData.get("email") as string)?.trim();
    const password = formData.get("password") as string;
    const confirmPassword = formData.get("confirm_password") as string;

    if (!orgName || !fullName || !email || !password) {
      return fail(400, {
        orgName,
        fullName,
        email,
        message: "All fields are required.",
      });
    }

    if (password.length < 6) {
      return fail(400, {
        orgName,
        fullName,
        email,
        message: "Password must be at least 6 characters.",
      });
    }

    if (password !== confirmPassword) {
      return fail(400, {
        orgName,
        fullName,
        email,
        message: "Passwords do not match.",
      });
    }

    const slug = slugify(orgName);
    if (!slug) {
      return fail(400, {
        orgName,
        fullName,
        email,
        message: "Organization name produces an invalid slug.",
      });
    }

    const { data: org, error: orgError } = await admin
      .from("organizations")
      .insert({ name: orgName, slug })
      .select("id")
      .single();

    if (orgError || !org) {
      return fail(500, {
        orgName,
        fullName,
        email,
        message: orgError?.message ?? "Failed to create organization.",
      });
    }

    const { data: authData, error: authError } =
      await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
      });

    if (authError || !authData.user) {
      await admin.from("organizations").delete().eq("id", org.id);
      return fail(500, {
        orgName,
        fullName,
        email,
        message: authError?.message ?? "Failed to create user.",
      });
    }

    const userId = authData.user.id;

    await admin
      .from("users")
      .update({ organization_id: org.id })
      .eq("id", userId);

    await admin.from("organization_members").insert({
      organization_id: org.id,
      user_id: userId,
      role_id: "a0000000-0000-0000-0000-000000000001",
    });

    await admin
      .from("system_config")
      .update({ platform_organization_id: org.id })
      .eq("id", config!.id);

    invalidateSetupCache();

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      redirect(303, "/login");
    }

    redirect(303, "/");
  },
};
