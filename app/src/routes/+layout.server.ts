import type { LayoutServerLoad } from "./$types";
import { getPlatformOrgId } from "$lib/server/setup-check";

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

  const platformOrgId = getPlatformOrgId();

  const queries: [
    Promise<{ data: any }>,
    Promise<{ data: any }>,
    Promise<{ count: number | null }> | null,
  ] = [
    supabase.rpc("get_user_role", {
      _user_id: authUser.id,
      _organization_id: organizationId,
    }),
    supabase.rpc("get_user_permissions", {
      _user_id: authUser.id,
      _organization_id: organizationId,
    }),
    platformOrgId
      ? supabase
          .from("organization_members")
          .select("*", { count: "exact", head: true })
          .eq("organization_id", platformOrgId)
          .eq("user_id", authUser.id)
      : null,
  ];

  const [{ data: roles }, { data: permissions }, memberResult] =
    await Promise.all(
      queries.map((q) => q ?? Promise.resolve({ count: null, data: null })),
    );

  const isPlatformMember = platformOrgId
    ? ((memberResult as { count: number | null }).count ?? 0) > 0
    : false;

  return {
    user,
    role: roles?.[0] ?? null,
    permissions: permissions ?? [],
    isPlatformMember,
  };
};