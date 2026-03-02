import { getClient } from "./client";
import { MEMBER_SELECT } from "./queries";

export const members = {
  async getAll(orgId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_members")
      .select(MEMBER_SELECT)
      .eq("organization_id", orgId)
      .order("created_at");

    if (error) throw error;
    return data ?? [];
  },

  async updateRole(orgId: string, userId: string, roleId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_members")
      .update({ role_id: roleId })
      .eq("organization_id", orgId)
      .eq("user_id", userId)
      .select(MEMBER_SELECT)
      .single();

    if (error) throw error;
    return data;
  },

  async remove(orgId: string, userId: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("organization_members")
      .delete()
      .eq("organization_id", orgId)
      .eq("user_id", userId);

    if (error) throw error;
  },

  async getRoles(orgId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("roles")
      .select(
        "*, permissions:role_permissions(*, permission:permissions(*))"
      )
      .or(`is_system.eq.true,organization_id.eq.${orgId}`)
      .order("is_system", { ascending: false })
      .order("name");

    if (error) throw error;
    return data ?? [];
  },
};