import { getClient } from "./client";

export type AppNotification = {
  id: string;
  organization_id: string;
  recipient_id: string;
  actor_id: string | null;
  type: string;
  title: string;
  body: string | null;
  resource_type: string | null;
  resource_id: string | null;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
  actor?: {
    id: string;
    full_name: string;
    avatar_url: string | null;
  } | null;
};

const NOTIFICATION_SELECT =
  "*, actor:users!actor_id(id, full_name, avatar_url)";

export const notificationsApi = {
  async getAll(page = 1, perPage = 20) {
    const supabase = getClient();
    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    const { data, error, count } = await supabase
      .from("notifications")
      .select(NOTIFICATION_SELECT, { count: "exact" })
      .order("created_at", { ascending: false })
      .range(from, to);

    if (error) throw error;
    return { data: (data ?? []) as AppNotification[], count: count ?? 0 };
  },

  async getUnreadCount() {
    const supabase = getClient();
    const { count, error } = await supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("is_read", false);

    if (error) throw error;
    return count ?? 0;
  },

  async markRead(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("notifications")
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq("id", id);

    if (error) throw error;
  },

  async markAllRead() {
    const supabase = getClient();
    const { error } = await supabase
      .from("notifications")
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq("is_read", false);

    if (error) throw error;
  },

  async remove(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("notifications")
      .delete()
      .eq("id", id);

    if (error) throw error;
  },
};
