import { getClient } from "./client";
import { TASK_SELECT, TASK_MINIMAL_SELECT } from "./queries";
import { indexDocument, deleteDocument } from "./search-index";

export type TaskFilters = {
  project_id?: string;
  status?: string;
  priority?: string;
  type?: string;
  created_by?: string;
  parent_id?: string | null;
  support_ticket_id?: string;
  search?: string;
};

export type CreateTaskInput = {
  title: string;
  description?: string;
  project_id: string;
  status?: string;
  priority?: string;
  type?: string;
  parent_id?: string;
  support_ticket_id?: string;
  start_at?: string;
  end_at?: string;
  created_by: string;
};

export const tasks = {
  async getAll(filters?: TaskFilters, page = 1, perPage = 25) {
    const supabase = getClient();
    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    let q = supabase
      .from("tasks")
      .select(TASK_SELECT, { count: "exact" })
      .is("deleted_at", null);

    if (filters?.project_id) q = q.eq("project_id", filters.project_id);
    if (filters?.status) q = q.eq("status", filters.status);
    if (filters?.priority) q = q.eq("priority", filters.priority);
    if (filters?.type) q = q.eq("type", filters.type);
    if (filters?.created_by) q = q.eq("created_by", filters.created_by);
    if (filters?.parent_id === null) q = q.is("parent_id", null);
    if (filters?.parent_id) q = q.eq("parent_id", filters.parent_id);
    if (filters?.support_ticket_id) q = q.eq("support_ticket_id", filters.support_ticket_id);
    if (filters?.search) q = q.ilike("title", `%${filters.search}%`);

    const { data, error, count } = await q
      .order("created_at", { ascending: false })
      .range(from, to);

    if (error) throw error;
    return { data: data ?? [], count: count ?? 0 };
  },

  async getById(id: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("tasks")
      .select(TASK_SELECT)
      .eq("id", id)
      .is("deleted_at", null)
      .single();

    if (error) throw error;
    return data;
  },

  async getByShortId(shortId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("tasks")
      .select(TASK_SELECT)
      .eq("short_id", shortId)
      .is("deleted_at", null)
      .single();

    if (error) throw error;
    return data;
  },

  async getByTicketId(ticketId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("tasks")
      .select(TASK_MINIMAL_SELECT)
      .eq("support_ticket_id", ticketId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false });

    if (error) throw error;
    return data ?? [];
  },

  async getSubtasks(parentId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("tasks")
      .select(TASK_MINIMAL_SELECT)
      .eq("parent_id", parentId)
      .is("deleted_at", null)
      .order("created_at");

    if (error) throw error;
    return data ?? [];
  },

  async create(input: CreateTaskInput) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("tasks")
      .insert(input)
      .select(TASK_SELECT)
      .single();

    if (error) throw error;
    if (data) indexDocument("task", data.id);
    return data;
  },

  async update(id: string, values: Record<string, unknown>) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("tasks")
      .update(values)
      .eq("id", id)
      .select(TASK_SELECT)
      .single();

    if (error) throw error;
    if (data) indexDocument("task", data.id);
    return data;
  },

  async updateStatus(id: string, status: string) {
    return tasks.update(id, { status });
  },

  async updatePriority(id: string, priority: string) {
    return tasks.update(id, { priority });
  },

  async delete(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("tasks")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", id);

    if (error) throw error;
    deleteDocument("task", id);
  },

  async assign(taskId: string, userId: string, assignedBy: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("task_assignments")
      .upsert(
        {
          task_id: taskId,
          user_id: userId,
          role: "assignee",
          assigned_by: assignedBy,
        },
        { onConflict: "task_id,user_id,role" }
      )
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  async unassign(taskId: string, userId: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("task_assignments")
      .delete()
      .eq("task_id", taskId)
      .eq("user_id", userId);

    if (error) throw error;
  },

  async getComments(taskId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("task_comments")
      .select("*, user:users(id, full_name, username, avatar_url)")
      .eq("task_id", taskId)
      .is("deleted_at", null)
      .order("created_at");

    if (error) throw error;
    return data ?? [];
  },

  async addComment(taskId: string, userId: string, content: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("task_comments")
      .insert({ task_id: taskId, user_id: userId, content })
      .select("*, user:users(id, full_name, username, avatar_url)")
      .single();

    if (error) throw error;
    if (data) indexDocument("task_comment", data.id);
    return data;
  },

  async updateCommentAttachments(commentId: string, attachmentIds: string[]) {
    const supabase = getClient();
    const { error } = await supabase
      .from("task_comments")
      .update({ attachment_ids: attachmentIds })
      .eq("id", commentId);

    if (error) throw error;
  },

  async getWorkLogs(taskId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("task_work_logs")
      .select("*, user:users(id, full_name, avatar_url)")
      .eq("task_id", taskId)
      .order("logged_at", { ascending: false })
      .order("created_at", { ascending: false });

    if (error) throw error;
    return data ?? [];
  },

  async addWorkLog(
    taskId: string,
    userId: string,
    minutes: number,
    description?: string,
    loggedAt?: string
  ) {
    const supabase = getClient();
    const row: Record<string, unknown> = {
      task_id: taskId,
      user_id: userId,
      minutes,
    };
    if (description) row.description = description;
    if (loggedAt) row.logged_at = loggedAt;

    const { data, error } = await supabase
      .from("task_work_logs")
      .insert(row)
      .select("*, user:users(id, full_name, avatar_url)")
      .single();

    if (error) throw error;
    return data;
  },

  async deleteWorkLog(id: string) {
    const supabase = getClient();
    const { error } = await supabase
      .from("task_work_logs")
      .delete()
      .eq("id", id);

    if (error) throw error;
  },

  async getActivities(taskId: string) {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("task_activities")
      .select("*, user:users(id, full_name, avatar_url)")
      .eq("task_id", taskId)
      .order("created_at", { ascending: false });

    if (error) throw error;
    return data ?? [];
  },
};