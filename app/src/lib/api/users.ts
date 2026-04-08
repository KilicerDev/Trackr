import { getClient } from "./client";

export type User = {
  id: string;
  email: string;
  full_name: string;
  username: string;
  avatar_url: string | null;
  timezone: string;
  locale: string;
  organization_id: string | null;
  is_active: boolean;
  last_seen_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

export type UserWithOrg = User & {
  organization: { id: string; name: string; slug: string } | null;
};

export type Invitation = {
  id: string;
  organization_id: string;
  email: string;
  role_id: string;
  invited_by: string;
  status: "pending" | "accepted" | "expired" | "revoked";
  expires_at: string;
  created_at: string;
  accepted_at: string | null;
  organization: { id: string; name: string; slug: string } | null;
  role: { id: string; name: string; slug: string } | null;
  inviter: { id: string; full_name: string } | null;
};

export type InviteInput = {
  email: string;
  full_name?: string;
  organization_id: string;
  role_id: string;
};

export type UpdateUserInput = {
  full_name?: string;
  username?: string;
  is_active?: boolean;
  timezone?: string;
  locale?: string;
  avatar_url?: string | null;
};

const USER_SELECT = `
  *,
  organization:organizations!organization_id(id, name, slug)
`;

const INVITATION_SELECT = `
  *,
  organization:organizations!organization_id(id, name, slug),
  role:roles!role_id(id, name, slug),
  inviter:users!invited_by(id, full_name)
`;

export const users = {
  async getAll() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("users")
      .select(USER_SELECT)
      .is("deleted_at", null)
      .order("created_at");

    if (error) throw error;
    return (data ?? []) as UserWithOrg[];
  },

  async getDeleted() {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("users")
      .select(USER_SELECT)
      .not("deleted_at", "is", null)
      .order("deleted_at", { ascending: false });

    if (error) throw error;
    return (data ?? []) as UserWithOrg[];
  },

  async reactivate(id: string, sendResetEmail = false) {
    const res = await fetch(`/api/users/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ send_reset_email: sendResetEmail }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      throw new Error(body?.message || `Reactivate failed (${res.status})`);
    }
    return res.json();
  },

  async getById(id: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("users")
      .select(USER_SELECT)
      .eq("id", id)
      .single();

    if (error) throw error;
    return data as UserWithOrg;
  },

  async update(id: string, values: UpdateUserInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("users")
      .update(values)
      .eq("id", id)
      .select(USER_SELECT)
      .single();

    if (error) throw error;
    return data as UserWithOrg;
  },

  async invite(input: InviteInput) {
    const res = await fetch("/api/invite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => null);
      throw new Error(body?.message || `Invite failed (${res.status})`);
    }

    return res.json();
  },

  async getInvitations(orgId?: string) {
    const supabase = getClient();
    let query = supabase
      .from("organization_invitations")
      .select(INVITATION_SELECT)
      .order("created_at", { ascending: false });

    if (orgId) {
      query = query.eq("organization_id", orgId);
    }

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as Invitation[];
  },

  async revokeInvitation(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("organization_invitations")
      .update({ status: "revoked" })
      .eq("id", id)
      .eq("status", "pending");

    if (error) throw error;
  },

  async getMemberships(userId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_members")
      .select(`
        *,
        organization:organizations!organization_id(id, name, slug),
        role:roles!role_id(id, name, slug)
      `)
      .eq("user_id", userId)
      .order("created_at");

    if (error) throw error;
    return data ?? [];
  },

  async addMembership(orgId: string, userId: string, roleId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_members")
      .insert({ organization_id: orgId, user_id: userId, role_id: roleId })
      .select(`
        *,
        organization:organizations!organization_id(id, name, slug),
        role:roles!role_id(id, name, slug)
      `)
      .single();

    if (error) throw error;
    return data;
  },

  async remove(id: string) {
    const res = await fetch(`/api/users/${id}`, { method: "DELETE" });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      throw new Error(body?.message || `Delete failed (${res.status})`);
    }
    return res.json();
  },

  async removeMembership(orgId: string, userId: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("organization_members")
      .delete()
      .eq("organization_id", orgId)
      .eq("user_id", userId);

    if (error) throw error;
  },

  async updateMembershipRole(orgId: string, userId: string, roleId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("organization_members")
      .update({ role_id: roleId })
      .eq("organization_id", orgId)
      .eq("user_id", userId)
      .select(`
        *,
        organization:organizations!organization_id(id, name, slug),
        role:roles!role_id(id, name, slug)
      `)
      .single();

    if (error) throw error;
    return data;
  },
};
