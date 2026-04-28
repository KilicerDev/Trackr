import { getClient } from "./client";

export type Permission = {
  id: string;
  resource: string;
  action: string;
  description: string | null;
};

export type RolePermission = {
  id: string;
  role_id: string;
  permission_id: string;
  scope: "own" | "all";
  permission: Permission;
};

export type Role = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  is_system: boolean;
  organization_id: string | null;
  created_at: string;
  updated_at: string;
  permissions: RolePermission[];
};

export type CreateRoleInput = {
  name: string;
  slug: string;
  description?: string | null;
  organization_id: string | null;
};

export type UpdateRoleInput = {
  name?: string;
  slug?: string;
  description?: string | null;
};

export type PermissionEntry = {
  permission_id: string;
  scope: "own" | "all";
};

const ROLE_SELECT = `
  *,
  permissions:role_permissions(*, permission:permissions(*))
`;

export const roles = {
  async getAll(orgId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("roles")
      .select(ROLE_SELECT)
      .or(`is_system.eq.true,organization_id.eq.${orgId},organization_id.is.null`)
      .order("is_system", { ascending: false })
      .order("name");

    if (error) throw error;
    return (data ?? []) as Role[];
  },

  async getForOrgs(orgIds: string[]) {
    const supabase = getClient();
    let query = supabase
      .from("roles")
      .select(ROLE_SELECT)
      .order("is_system", { ascending: false })
      .order("name");

    if (orgIds.length > 0) {
      const list = orgIds.map((id) => `"${id}"`).join(",");
      query = query.or(
        `is_system.eq.true,organization_id.in.(${list}),organization_id.is.null`
      );
    } else {
      query = query.or("is_system.eq.true,organization_id.is.null");
    }

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as Role[];
  },

  async getPermissions() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("permissions")
      .select("*")
      .order("resource")
      .order("action");

    if (error) throw error;
    return (data ?? []) as Permission[];
  },

  async create(input: CreateRoleInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("roles")
      .insert({ ...input, is_system: false })
      .select(ROLE_SELECT)
      .single();

    if (error) throw error;
    return data as Role;
  },

  async update(id: string, values: UpdateRoleInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("roles")
      .update(values)
      .eq("id", id)
      .select(ROLE_SELECT)
      .single();

    if (error) throw error;
    return data as Role;
  },

  async delete(id: string) {
    const supabase = getClient();
    const { error } = await supabase.from("roles").delete().eq("id", id);

    if (error) throw error;
  },

  async setPermissions(roleId: string, entries: PermissionEntry[]) {
    const supabase = getClient();

    const { error: delError } = await supabase
      .from("role_permissions")
      .delete()
      .eq("role_id", roleId);

    if (delError) throw delError;

    if (entries.length === 0) return;

    const rows = entries.map((e) => ({
      role_id: roleId,
      permission_id: e.permission_id,
      scope: e.scope,
    }));

    const { error: insError } = await supabase
      .from("role_permissions")
      .insert(rows);

    if (insError) throw insError;
  },
};
