import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({
  locals: { supabase, user: authUser },
}) => {
  if (!authUser) {
    return { user: null, role: null, permissions: [], isPlatformMember: false };
  }

  const { data: user } = await supabase
    .from("users")
    .select("*")
    .eq("id", authUser.id)
    .single();

  if (!user) {
    return { user: null, role: null, permissions: [], isPlatformMember: false };
  }

  const organizationId = user.organization_id ?? null;

  if (!organizationId) {
    return { user, role: null, permissions: [], isPlatformMember: false };
  }

  const [{ data: roles }, { data: permissions }, { data: config }] =
    await Promise.all([
      supabase.rpc("get_user_role", {
        _user_id: authUser.id,
        _organization_id: organizationId,
      }),
      supabase.rpc("get_user_permissions", {
        _user_id: authUser.id,
        _organization_id: organizationId,
      }),
      supabase
        .from("system_config")
        .select("platform_organization_id")
        .limit(1)
        .single(),
    ]);

  const platformOrgId = config?.platform_organization_id ?? null;
  let isPlatformMember = false;

  if (platformOrgId) {
    const { count } = await supabase
      .from("organization_members")
      .select("*", { count: "exact", head: true })
      .eq("organization_id", platformOrgId)
      .eq("user_id", authUser.id);
    isPlatformMember = (count ?? 0) > 0;
  }

  return {
    user,
    role: roles?.[0] ?? null,
    permissions: permissions ?? [],
    isPlatformMember,
  };
};