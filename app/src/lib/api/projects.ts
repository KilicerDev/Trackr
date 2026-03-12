import { getClient } from "./client";
import { PROJECT_SELECT } from "./queries";

export type CreateProjectInput = {
  name: string;
  identifier: string;
  description?: string;
  owner_id: string;
  organization_id: string;
  status?: string;
  color?: string;
  icon?: string;
  start_at?: string;
  end_at?: string;
};

export const projects = {
  async getAll(orgId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("projects")
      .select(PROJECT_SELECT)
      .eq("organization_id", orgId)
      .is("deleted_at", null)
      .order("name");

    if (error) throw error;
    return data ?? [];
  },

  async getAllAcrossOrgs() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("projects")
      .select(`${PROJECT_SELECT}, organization:organizations!organization_id(id, name)`)
      .is("deleted_at", null)
      .order("organization_id")
      .order("name");

    if (error) throw error;
    return data ?? [];
  },

  async getById(id: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("projects")
      .select(PROJECT_SELECT)
      .eq("id", id)
      .is("deleted_at", null)
      .single();

    if (error) throw error;
    return data;
  },

  async create(input: CreateProjectInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("projects")
      .insert(input)
      .select(PROJECT_SELECT)
      .single();

    if (error) throw error;
    return data;
  },

  async update(id: string, values: Record<string, unknown>) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("projects")
      .update(values)
      .eq("id", id)
      .select(PROJECT_SELECT)
      .single();

    if (error) throw error;
    return data;
  },

  async delete(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("projects")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", id);

    if (error) throw error;
  },

  async addMember(projectId: string, userId: string, roleId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("project_members")
      .upsert(
        { project_id: projectId, user_id: userId, role_id: roleId },
        { onConflict: "project_id,user_id" }
      )
      .select(
        "*, user:users(id, full_name, avatar_url), role:roles(id, name)"
      )
      .single();

    if (error) throw error;
    return data;
  },

  async removeMember(projectId: string, userId: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("project_members")
      .delete()
      .eq("project_id", projectId)
      .eq("user_id", userId);

    if (error) throw error;
  },
};