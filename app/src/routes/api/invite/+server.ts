import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { getAdminClient } from "$lib/server/supabase-admin";

export const POST: RequestHandler = async ({ request, locals }) => {
  const session = locals.session;
  if (!session) {
    throw error(401, "Not authenticated");
  }

  const body = await request.json();
  const { email, full_name, organization_id, role_id } = body;

  if (!email || !organization_id || !role_id) {
    throw error(400, "Missing required fields: email, organization_id, role_id");
  }

  const supabase = locals.supabase;

  const { data: hasPermission } = await supabase.rpc("user_has_permission", {
    _user_id: session.user.id,
    _organization_id: organization_id,
    _resource: "members",
    _action: "invite",
  });

  if (!hasPermission) {
    throw error(403, "You do not have permission to invite users");
  }

  // Validate role is allowed for target organization type
  const { data: sysConfig } = await supabase
    .from("system_config")
    .select("platform_organization_id")
    .single();

  const { data: role } = await supabase
    .from("roles")
    .select("slug")
    .eq("id", role_id)
    .single();

  if (role?.slug === "owner") {
    throw error(400, "The owner role cannot be assigned");
  }
  const isPlatformOrg =
    sysConfig?.platform_organization_id === organization_id;
  if (isPlatformOrg && role?.slug === "client") {
    throw error(
      400,
      "Client role cannot be assigned to the platform organization"
    );
  }
  if (!isPlatformOrg && role?.slug === "admin") {
    throw error(
      400,
      "Admin role can only be assigned to the platform organization"
    );
  }

  const { data: existing } = await supabase
    .from("organization_invitations")
    .select("id, status")
    .eq("organization_id", organization_id)
    .eq("email", email)
    .single();

  if (existing?.status === "pending") {
    throw error(409, "An invitation for this email already exists in this organization");
  }

  if (existing?.status === "accepted") {
    throw error(409, "This user has already accepted an invitation to this organization");
  }

  // If there's an expired/revoked invitation, delete it so we can create a fresh one
  if (existing) {
    await supabase
      .from("organization_invitations")
      .delete()
      .eq("id", existing.id);
  }

  // Check if the user already exists and is already a member
  const { data: existingUser } = await supabase
    .from("users")
    .select("id")
    .eq("email", email)
    .single();

  if (existingUser) {
    const { data: existingMember } = await supabase
      .from("organization_members")
      .select("id")
      .eq("organization_id", organization_id)
      .eq("user_id", existingUser.id)
      .single();

    if (existingMember) {
      throw error(409, "This user is already a member of this organization");
    }

    // User exists but is not a member — add them directly
    const { error: memberErr } = await supabase
      .from("organization_members")
      .insert({
        organization_id,
        user_id: existingUser.id,
        role_id,
      });

    if (memberErr) throw error(500, memberErr.message);

    // Create an already-accepted invitation record for audit purposes
    const { data: invitation, error: invErr } = await supabase
      .from("organization_invitations")
      .insert({
        organization_id,
        email,
        role_id,
        invited_by: session.user.id,
        status: "accepted",
        accepted_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (invErr) throw error(500, invErr.message);

    return json({ invitation, added_directly: true });
  }

  // User doesn't exist — create invitation and send Supabase invite email
  const { data: invitation, error: invErr } = await supabase
    .from("organization_invitations")
    .insert({
      organization_id,
      email,
      role_id,
      invited_by: session.user.id,
    })
    .select()
    .single();

  if (invErr) throw error(500, invErr.message);

  const adminClient = getAdminClient();
  const { error: authErr } = await adminClient.auth.admin.inviteUserByEmail(
    email,
    {
      data: {
        full_name: full_name || "",
        organization_id,
        role_id,
      },
      redirectTo: `${new URL(request.url).origin}/auth/callback`,
    }
  );

  if (authErr) {
    // Roll back the invitation if auth invite fails
    await supabase
      .from("organization_invitations")
      .delete()
      .eq("id", invitation.id);
    throw error(500, authErr.message);
  }

  return json({ invitation, added_directly: false });
};
