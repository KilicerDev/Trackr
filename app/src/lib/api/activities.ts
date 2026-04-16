import { getClient } from "./client";

export type ActivityLogSourceType =
  | "task"
  | "ticket"
  | "wiki_page"
  | "wiki_folder"
  | "wiki_file";

export type ActivityLogEntry = {
  id: string;
  source_type: ActivityLogSourceType;
  source_id: string;
  source_label: string;
  source_project_id: string | null;
  user_id: string;
  user_name: string;
  user_avatar: string | null;
  action: string;
  field_name: string | null;
  old_value: string | null;
  new_value: string | null;
  created_at: string;
};

export type ActivityLogFilter = "all" | "task" | "ticket" | "wiki";

export const activities = {
  async getLogs(type: ActivityLogFilter = "all", page = 1, perPage = 25) {
    const supabase = getClient();
    const offset = (page - 1) * perPage;

    const [{ data, error }, { data: countData, error: countError }] =
      await Promise.all([
        supabase.rpc("get_admin_activity_log", {
          _type: type,
          _limit: perPage,
          _offset: offset,
        }),
        supabase.rpc("get_admin_activity_log_count", {
          _type: type,
        }),
      ]);

    if (error) throw error;
    if (countError) throw countError;

    return {
      data: (data ?? []) as ActivityLogEntry[],
      count: (countData as number) ?? 0,
    };
  },
};
