import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { getAdminClient } from "$lib/server/supabase-admin";

export const DELETE: RequestHandler = async ({ params, locals }) => {
  const session = locals.session;
  if (!session) {
    throw error(401, "Not authenticated");
  }

  const userId = params.id;

  if (session.user.id === userId) {
    throw error(400, "You cannot delete your own account");
  }

  const supabase = locals.supabase;

  // Check permission — reuse members:remove
  const { data: hasPermission } = await supabase.rpc("user_has_permission", {
    _user_id: session.user.id,
    _organization_id: null,
    _resource: "members",
    _action: "remove",
  });

  if (!hasPermission) {
    throw error(403, "You do not have permission to delete users");
  }

  const adminClient = getAdminClient();

  // Soft delete: set deleted_at and is_active = false
  // Access is revoked via is_active check in hooks.server.ts
  const { error: updateErr } = await adminClient
    .from("users")
    .update({
      deleted_at: new Date().toISOString(),
      is_active: false,
    })
    .eq("id", userId);

  if (updateErr) {
    throw error(500, updateErr.message);
  }

  return json({ success: true });
};

export const PATCH: RequestHandler = async ({ params, locals, request, url }) => {
  const session = locals.session;
  if (!session) {
    throw error(401, "Not authenticated");
  }

  const userId = params.id;
  const supabase = locals.supabase;

  // Check permission — reuse members:remove
  const { data: hasPermission } = await supabase.rpc("user_has_permission", {
    _user_id: session.user.id,
    _organization_id: null,
    _resource: "members",
    _action: "remove",
  });

  if (!hasPermission) {
    throw error(403, "You do not have permission to reactivate users");
  }

  const adminClient = getAdminClient();

  // Reactivate: clear deleted_at, set is_active = true
  const { error: updateErr } = await adminClient
    .from("users")
    .update({ deleted_at: null, is_active: true })
    .eq("id", userId);

  if (updateErr) {
    throw error(500, updateErr.message);
  }

  // Optionally send password reset email
  const body = await request.json().catch(() => ({}));
  if (body.send_reset_email) {
    const { data: user } = await adminClient
      .from("users")
      .select("email")
      .eq("id", userId)
      .single();

    if (user?.email) {
      await adminClient.auth.resetPasswordForEmail(user.email, {
        redirectTo: `${url.origin}/auth/callback`,
      });
    }
  }

  return json({ success: true });
};
