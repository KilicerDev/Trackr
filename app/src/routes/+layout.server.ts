import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({
  locals: { supabase, user: authUser },
}) => {
  if (!authUser) {
    return { user: null, role: null, permissions: [] };
  }

  const { data: user } = await supabase
    .from("users")
    .select("*")
    .eq("id", authUser.id)
    .single();

  if (!user) {
    return { user: null, role: null, permissions: [] };
  }

  const organizationId = user.organization_id ?? null;

  if (!organizationId) {
    return { user, role: null, permissions: [] };
  }

  const [{ data: roles }, { data: permissions }] = await Promise.all([
    supabase.rpc("get_user_role", {
      _user_id: authUser.id,
      _organization_id: organizationId,
    }),
    supabase.rpc("get_user_permissions", {
      _user_id: authUser.id,
      _organization_id: organizationId,
    }),
  ]);

  return {
    user,
    role: roles?.[0] ?? null,
    permissions: permissions ?? [],
  };
};