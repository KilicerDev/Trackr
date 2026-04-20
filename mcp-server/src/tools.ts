import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { readFile } from "node:fs/promises";
import { basename, isAbsolute } from "node:path";
import { currentUserId } from "./supabase.js";

const TASK_STATUS = [
  "backlog",
  "todo",
  "in_progress",
  "in_review",
  "done",
  "cancelled",
] as const;
const TASK_PRIORITY = ["none", "low", "medium", "high", "urgent"] as const;
const TASK_TYPE = ["task", "bug", "feature", "improvement", "epic"] as const;
const TICKET_STATUS = [
  "open",
  "in_progress",
  "waiting_on_customer",
  "waiting_on_agent",
  "resolved",
  "closed",
] as const;
const TICKET_PRIORITY = ["low", "medium", "high", "urgent"] as const;
const TICKET_CATEGORY = [
  "billing",
  "technical_issue",
  "feature_request",
  "general",
] as const;
const TICKET_CHANNEL = ["email", "api", "chat", "web_form"] as const;
const PROJECT_STATUS = [
  "planning",
  "active",
  "paused",
  "completed",
  "archived",
] as const;
const ATTACHMENT_ENTITY_TYPE = [
  "task",
  "task_comment",
  "support_ticket",
  "ticket_message",
  "project",
] as const;

const ATTACHMENT_MIME_ALLOWLIST = new Set([
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
  "image/svg+xml",
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "text/plain",
  "text/csv",
]);

const ATTACHMENT_MAX_BYTES = 52_428_800;

const EXTENSION_TO_MIME: Record<string, string> = {
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  gif: "image/gif",
  webp: "image/webp",
  svg: "image/svg+xml",
  pdf: "application/pdf",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  xls: "application/vnd.ms-excel",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ppt: "application/vnd.ms-powerpoint",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  txt: "text/plain",
  csv: "text/csv",
};

function inferMimeFromFileName(fileName: string): string | undefined {
  const dot = fileName.lastIndexOf(".");
  if (dot < 0 || dot === fileName.length - 1) return undefined;
  return EXTENSION_TO_MIME[fileName.slice(dot + 1).toLowerCase()];
}

async function resolveEntityOrgId(
  db: SupabaseClient,
  entityType: (typeof ATTACHMENT_ENTITY_TYPE)[number],
  entityId: string,
): Promise<string> {
  if (entityType === "project") {
    const { data, error } = await db
      .from("projects")
      .select("organization_id")
      .eq("id", entityId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error(`project ${entityId} not found or not accessible`);
    return data.organization_id as string;
  }
  if (entityType === "task") {
    const { data, error } = await db
      .from("tasks")
      .select("project:projects!inner(organization_id)")
      .eq("id", entityId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    const org = (data as any)?.project?.organization_id as string | undefined;
    if (!org) throw new Error(`task ${entityId} not found or not accessible`);
    return org;
  }
  if (entityType === "task_comment") {
    const { data, error } = await db
      .from("task_comments")
      .select("task:tasks!inner(project:projects!inner(organization_id))")
      .eq("id", entityId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    const org = (data as any)?.task?.project?.organization_id as
      | string
      | undefined;
    if (!org)
      throw new Error(`task_comment ${entityId} not found or not accessible`);
    return org;
  }
  if (entityType === "support_ticket") {
    const { data, error } = await db
      .from("support_tickets")
      .select("organization_id")
      .eq("id", entityId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data)
      throw new Error(`support_ticket ${entityId} not found or not accessible`);
    return data.organization_id as string;
  }
  const { data, error } = await db
    .from("support_ticket_messages")
    .select("ticket:support_tickets!inner(organization_id)")
    .eq("id", entityId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  const org = (data as any)?.ticket?.organization_id as string | undefined;
  if (!org)
    throw new Error(`ticket_message ${entityId} not found or not accessible`);
  return org;
}

function json(payload: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(payload, null, 2) }],
  };
}

function err(message: string) {
  return {
    isError: true,
    content: [{ type: "text" as const, text: message }],
  };
}

function resolveOrgId(explicit?: string | null): string | undefined {
  return explicit ?? process.env.TRACKR_ORG_ID ?? undefined;
}

function requireOrgId(explicit?: string | null): string {
  const id = resolveOrgId(explicit);
  if (!id)
    throw new Error(
      "organization_id is required (pass it as an argument or set TRACKR_ORG_ID)",
    );
  return id;
}

export function registerTools(server: McpServer, db: SupabaseClient): void {
  server.tool(
    "trackr_whoami",
    "Return the current authenticated user's id, email and username.",
    {},
    async () => {
      const { data: auth, error } = await db.auth.getUser();
      if (error || !auth.user) return err(error?.message ?? "Not authenticated");
      const { data: profile } = await db
        .from("users")
        .select("id, email, username, organization_id")
        .eq("id", auth.user.id)
        .maybeSingle();
      return json({ auth: auth.user, profile });
    },
  );

  server.tool(
    "trackr_org_list",
    "List organizations the current user is a member of. Use this to discover organization_id values.",
    {},
    async () => {
      const { data, error } = await db
        .from("organization_members")
        .select("role_id, organization:organizations(id, slug, name, domain)");
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_user_search",
    "Search users by email or username substring. Returns up to 20 matches.",
    {
      query: z.string().min(1),
    },
    async ({ query }) => {
      const like = `%${query}%`;
      const { data, error } = await db
        .from("users")
        .select("id, email, username, organization_id")
        .or(`email.ilike.${like},username.ilike.${like}`)
        .limit(20);
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_project_list",
    "List projects the user can access. Optionally filter by status.",
    {
      organization_id: z.string().uuid().optional(),
      status: z.enum(PROJECT_STATUS).optional(),
      limit: z.number().int().min(1).max(200).default(50),
    },
    async ({ organization_id, status, limit }) => {
      let q = db
        .from("projects")
        .select("id, identifier, name, status, organization_id, owner_id, created_at")
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(limit);
      const org = resolveOrgId(organization_id);
      if (org) q = q.eq("organization_id", org);
      if (status) q = q.eq("status", status);
      const { data, error } = await q;
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_project_get",
    "Get a single project by id.",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { data, error } = await db
        .from("projects")
        .select("*")
        .eq("id", id)
        .maybeSingle();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_project_create",
    "Create a new project. identifier is a short uppercase key (<=10 chars) used for task short ids.",
    {
      name: z.string().min(1),
      identifier: z.string().min(1).max(10),
      description: z.string().optional(),
      status: z.enum(PROJECT_STATUS).default("active"),
      organization_id: z.string().uuid().optional(),
    },
    async ({ name, identifier, description, status, organization_id }) => {
      try {
        const org = requireOrgId(organization_id);
        const owner = await currentUserId(db);
        const { data, error } = await db
          .from("projects")
          .insert({
            name,
            identifier: identifier.toUpperCase(),
            description,
            status,
            organization_id: org,
            owner_id: owner,
          })
          .select()
          .single();
        if (error) return err(error.message);
        return json(data);
      } catch (e) {
        return err((e as Error).message);
      }
    },
  );

  server.tool(
    "trackr_project_update",
    "Update fields on a project.",
    {
      id: z.string().uuid(),
      name: z.string().optional(),
      description: z.string().optional(),
      status: z.enum(PROJECT_STATUS).optional(),
    },
    async ({ id, ...patch }) => {
      const { data, error } = await db
        .from("projects")
        .update(patch)
        .eq("id", id)
        .select()
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_task_list",
    "List tasks with optional filters. Defaults to non-deleted tasks, newest first.",
    {
      project_id: z.string().uuid().optional(),
      status: z.enum(TASK_STATUS).optional(),
      priority: z.enum(TASK_PRIORITY).optional(),
      type: z.enum(TASK_TYPE).optional(),
      assignee_id: z.string().uuid().optional(),
      search: z
        .string()
        .optional()
        .describe("Substring match on title"),
      limit: z.number().int().min(1).max(200).default(50),
    },
    async ({ project_id, status, priority, type, assignee_id, search, limit }) => {
      let q = db
        .from("tasks")
        .select(
          "id, short_id, title, status, priority, type, project_id, created_by, start_at, end_at, created_at",
        )
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (project_id) q = q.eq("project_id", project_id);
      if (status) q = q.eq("status", status);
      if (priority) q = q.eq("priority", priority);
      if (type) q = q.eq("type", type);
      if (search) q = q.ilike("title", `%${search}%`);
      const { data, error } = await q;
      if (error) return err(error.message);
      if (assignee_id && data) {
        const ids = data.map((t) => t.id);
        const { data: a } = await db
          .from("task_assignments")
          .select("task_id")
          .eq("user_id", assignee_id)
          .in("task_id", ids);
        const keep = new Set((a ?? []).map((x) => x.task_id));
        return json(data.filter((t) => keep.has(t.id)));
      }
      return json(data);
    },
  );

  server.tool(
    "trackr_task_get",
    "Get one task by id, including assignments, tags and recent comments.",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { data: task, error } = await db
        .from("tasks")
        .select("*")
        .eq("id", id)
        .maybeSingle();
      if (error) return err(error.message);
      if (!task) return json(null);
      const [{ data: assignments }, { data: tags }, { data: comments }] =
        await Promise.all([
          db
            .from("task_assignments")
            .select("user_id, role")
            .eq("task_id", id),
          db
            .from("task_tags")
            .select("tag:tags(id, name, color)")
            .eq("task_id", id),
          db
            .from("task_comments")
            .select("id, content, created_by, created_at")
            .eq("task_id", id)
            .is("deleted_at", null)
            .order("created_at", { ascending: false })
            .limit(20),
        ]);
      return json({ ...task, assignments, tags, comments });
    },
  );

  server.tool(
    "trackr_task_create",
    "Create a task in a project.",
    {
      project_id: z.string().uuid(),
      title: z.string().min(1),
      description: z.string().optional(),
      status: z.enum(TASK_STATUS).default("todo"),
      priority: z.enum(TASK_PRIORITY).default("none"),
      type: z.enum(TASK_TYPE).default("task"),
      parent_id: z.string().uuid().optional(),
      support_ticket_id: z.string().uuid().optional(),
      start_at: z.string().datetime().optional(),
      end_at: z.string().datetime().optional(),
      assignee_ids: z.array(z.string().uuid()).optional(),
    },
    async ({ assignee_ids, ...fields }) => {
      let createdBy: string;
      try {
        createdBy = await currentUserId(db);
      } catch (e) {
        return err((e as Error).message);
      }
      const { data: task, error } = await db
        .from("tasks")
        .insert({ ...fields, created_by: createdBy })
        .select()
        .single();
      if (error) return err(error.message);
      if (assignee_ids?.length) {
        const rows = assignee_ids.map((user_id) => ({
          task_id: task.id,
          user_id,
          role: "assignee",
        }));
        const { error: aerr } = await db.from("task_assignments").insert(rows);
        if (aerr) return err(`task created but assignment failed: ${aerr.message}`);
      }
      return json(task);
    },
  );

  server.tool(
    "trackr_task_update",
    "Update fields on a task.",
    {
      id: z.string().uuid(),
      title: z.string().optional(),
      description: z.string().optional(),
      status: z.enum(TASK_STATUS).optional(),
      priority: z.enum(TASK_PRIORITY).optional(),
      type: z.enum(TASK_TYPE).optional(),
      start_at: z.string().datetime().nullable().optional(),
      end_at: z.string().datetime().nullable().optional(),
    },
    async ({ id, ...patch }) => {
      const { data, error } = await db
        .from("tasks")
        .update(patch)
        .eq("id", id)
        .select()
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_task_delete",
    "Soft-delete a task (sets deleted_at).",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { error } = await db
        .from("tasks")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", id);
      if (error) return err(error.message);
      return json({ id, deleted: true });
    },
  );

  server.tool(
    "trackr_task_comment_add",
    "Add a comment to a task.",
    {
      task_id: z.string().uuid(),
      content: z.string().min(1),
    },
    async ({ task_id, content }) => {
      let userId: string;
      try {
        userId = await currentUserId(db);
      } catch (e) {
        return err((e as Error).message);
      }
      const { data, error } = await db
        .from("task_comments")
        .insert({ task_id, content, user_id: userId })
        .select()
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_task_work_log_add",
    "Log time spent on a task. Minutes must be > 0. logged_at is a calendar date (YYYY-MM-DD); defaults to today.",
    {
      task_id: z.string().uuid(),
      minutes: z.number().int().positive(),
      description: z.string().optional(),
      logged_at: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/, "logged_at must be YYYY-MM-DD")
        .optional(),
    },
    async ({ task_id, minutes, description, logged_at }) => {
      let userId: string;
      try {
        userId = await currentUserId(db);
      } catch (e) {
        return err((e as Error).message);
      }
      const row: Record<string, unknown> = { task_id, user_id: userId, minutes };
      if (description) row.description = description;
      if (logged_at) row.logged_at = logged_at;
      const { data, error } = await db
        .from("task_work_logs")
        .insert(row)
        .select("*, user:users(id, full_name, avatar_url)")
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_ticket_list",
    "List support tickets with optional filters.",
    {
      organization_id: z.string().uuid().optional(),
      status: z.enum(TICKET_STATUS).optional(),
      priority: z.enum(TICKET_PRIORITY).optional(),
      category: z.enum(TICKET_CATEGORY).optional(),
      assigned_agent_id: z.string().uuid().optional(),
      customer_id: z.string().uuid().optional(),
      search: z.string().optional().describe("Substring match on subject"),
      limit: z.number().int().min(1).max(200).default(50),
    },
    async ({
      organization_id,
      status,
      priority,
      category,
      assigned_agent_id,
      customer_id,
      search,
      limit,
    }) => {
      let q = db
        .from("support_tickets")
        .select(
          "id, subject, status, priority, category, channel, organization_id, customer_id, assigned_agent_id, sla_deadline, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(limit);
      const org = resolveOrgId(organization_id);
      if (org) q = q.eq("organization_id", org);
      if (status) q = q.eq("status", status);
      if (priority) q = q.eq("priority", priority);
      if (category) q = q.eq("category", category);
      if (assigned_agent_id) q = q.eq("assigned_agent_id", assigned_agent_id);
      if (customer_id) q = q.eq("customer_id", customer_id);
      if (search) q = q.ilike("subject", `%${search}%`);
      const { data, error } = await q;
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_ticket_get",
    "Get one support ticket with its messages.",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { data: ticket, error } = await db
        .from("support_tickets")
        .select("*")
        .eq("id", id)
        .maybeSingle();
      if (error) return err(error.message);
      if (!ticket) return json(null);
      const { data: messages } = await db
        .from("support_ticket_messages")
        .select("id, sender_id, content, created_at")
        .eq("ticket_id", id)
        .order("created_at", { ascending: true });
      return json({ ...ticket, messages });
    },
  );

  server.tool(
    "trackr_ticket_create",
    "Open a new support ticket.",
    {
      subject: z.string().min(1),
      description: z.string().optional(),
      priority: z.enum(TICKET_PRIORITY).default("medium"),
      category: z.enum(TICKET_CATEGORY).default("general"),
      channel: z.enum(TICKET_CHANNEL).default("api"),
      customer_id: z.string().uuid().optional(),
      organization_id: z.string().uuid().optional(),
    },
    async ({ organization_id, customer_id, ...fields }) => {
      try {
        const org = requireOrgId(organization_id);
        const customer = customer_id ?? (await currentUserId(db));
        const { data, error } = await db
          .from("support_tickets")
          .insert({ ...fields, organization_id: org, customer_id: customer })
          .select()
          .single();
        if (error) return err(error.message);
        return json(data);
      } catch (e) {
        return err((e as Error).message);
      }
    },
  );

  server.tool(
    "trackr_ticket_update",
    "Update fields on a support ticket (status, priority, assignee, etc.).",
    {
      id: z.string().uuid(),
      subject: z.string().optional(),
      status: z.enum(TICKET_STATUS).optional(),
      priority: z.enum(TICKET_PRIORITY).optional(),
      category: z.enum(TICKET_CATEGORY).optional(),
      assigned_agent_id: z.string().uuid().nullable().optional(),
      satisfaction_score: z.number().int().min(1).max(5).optional(),
    },
    async ({ id, ...patch }) => {
      const { data, error } = await db
        .from("support_tickets")
        .update(patch)
        .eq("id", id)
        .select()
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_ticket_message_add",
    "Add a message (public reply) to a support ticket.",
    {
      ticket_id: z.string().uuid(),
      content: z.string().min(1),
    },
    async ({ ticket_id, content }) => {
      let senderId: string;
      try {
        senderId = await currentUserId(db);
      } catch (e) {
        return err((e as Error).message);
      }
      const { data, error } = await db
        .from("support_ticket_messages")
        .insert({ ticket_id, body: content, sender_id: senderId })
        .select()
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_wiki_folder_list",
    "List wiki folders, optionally under a specific parent.",
    {
      organization_id: z.string().uuid().optional(),
      parent_id: z.string().uuid().nullable().optional(),
    },
    async ({ organization_id, parent_id }) => {
      let q = db
        .from("wiki_folders")
        .select("id, name, parent_id, position, organization_id, created_by")
        .order("position", { ascending: true });
      const org = resolveOrgId(organization_id);
      if (org) q = q.eq("organization_id", org);
      if (parent_id === null) q = q.is("parent_id", null);
      else if (parent_id) q = q.eq("parent_id", parent_id);
      const { data, error } = await q;
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_wiki_folder_create",
    "Create a new wiki folder.",
    {
      name: z.string().min(1),
      parent_id: z.string().uuid().nullable().optional(),
      position: z.number().int().optional(),
      organization_id: z.string().uuid().optional(),
    },
    async ({ organization_id, ...fields }) => {
      try {
        const org = requireOrgId(organization_id);
        const createdBy = await currentUserId(db);
        const { data, error } = await db
          .from("wiki_folders")
          .insert({ ...fields, organization_id: org, created_by: createdBy })
          .select()
          .single();
        if (error) return err(error.message);
        return json(data);
      } catch (e) {
        return err((e as Error).message);
      }
    },
  );

  server.tool(
    "trackr_wiki_page_list",
    "List wiki pages, optionally under a folder or matching a title substring.",
    {
      organization_id: z.string().uuid().optional(),
      folder_id: z.string().uuid().nullable().optional(),
      search: z.string().optional(),
      limit: z.number().int().min(1).max(200).default(50),
    },
    async ({ organization_id, folder_id, search, limit }) => {
      let q = db
        .from("wiki_pages")
        .select(
          "id, title, folder_id, organization_id, icon, position, created_by, updated_by, created_at, updated_at",
        )
        .is("deleted_at", null)
        .order("position", { ascending: true })
        .limit(limit);
      const org = resolveOrgId(organization_id);
      if (org) q = q.eq("organization_id", org);
      if (folder_id === null) q = q.is("folder_id", null);
      else if (folder_id) q = q.eq("folder_id", folder_id);
      if (search) q = q.ilike("title", `%${search}%`);
      const { data, error } = await q;
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_wiki_page_get",
    "Get a wiki page with its full content.",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { data, error } = await db
        .from("wiki_pages")
        .select("*")
        .eq("id", id)
        .is("deleted_at", null)
        .maybeSingle();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_wiki_page_create",
    "Create a new wiki page. Content is markdown or the editor's native format.",
    {
      title: z.string().min(1),
      content: z.string().default(""),
      folder_id: z.string().uuid().nullable().optional(),
      icon: z.string().optional(),
      position: z.number().int().optional(),
      organization_id: z.string().uuid().optional(),
    },
    async ({ organization_id, ...fields }) => {
      try {
        const org = requireOrgId(organization_id);
        const createdBy = await currentUserId(db);
        const { data, error } = await db
          .from("wiki_pages")
          .insert({ ...fields, organization_id: org, created_by: createdBy })
          .select()
          .single();
        if (error) return err(error.message);
        return json(data);
      } catch (e) {
        return err((e as Error).message);
      }
    },
  );

  server.tool(
    "trackr_wiki_page_update",
    "Update a wiki page's title, content, folder or icon.",
    {
      id: z.string().uuid(),
      title: z.string().optional(),
      content: z.string().optional(),
      folder_id: z.string().uuid().nullable().optional(),
      icon: z.string().optional(),
      position: z.number().int().optional(),
    },
    async ({ id, ...patch }) => {
      const { data, error } = await db
        .from("wiki_pages")
        .update(patch)
        .eq("id", id)
        .select()
        .single();
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_wiki_page_delete",
    "Soft-delete a wiki page.",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { error } = await db
        .from("wiki_pages")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", id);
      if (error) return err(error.message);
      return json({ id, deleted: true });
    },
  );

  server.tool(
    "trackr_attachment_add",
    "Attach a file to a task, task_comment, support_ticket, ticket_message or project. Provide EITHER an absolute local file path OR an https URL (not both). Max 50MB; mime_type must be in the bucket allowlist (images, PDF, Office docs, text/CSV).",
    {
      entity_type: z.enum(ATTACHMENT_ENTITY_TYPE),
      entity_id: z.string().uuid(),
      path: z
        .string()
        .optional()
        .describe("Absolute local file path. Mutually exclusive with url."),
      url: z
        .string()
        .url()
        .optional()
        .describe("HTTPS URL to fetch. Mutually exclusive with path."),
      file_name: z
        .string()
        .min(1)
        .optional()
        .describe("Override the inferred basename."),
      mime_type: z
        .string()
        .min(1)
        .optional()
        .describe("Override the inferred content type."),
    },
    async ({ entity_type, entity_id, path: filePath, url, file_name, mime_type }) => {
      try {
        if ((filePath && url) || (!filePath && !url)) {
          return err("provide exactly one of path or url");
        }
        const uploadedBy = await currentUserId(db);
        const orgId = await resolveEntityOrgId(db, entity_type, entity_id);

        let bytes: Uint8Array;
        let resolvedName = file_name;
        let resolvedMime = mime_type;

        if (filePath) {
          if (!isAbsolute(filePath)) {
            return err(`path must be absolute, got: ${filePath}`);
          }
          const buf = await readFile(filePath);
          bytes = new Uint8Array(buf);
          resolvedName = resolvedName ?? basename(filePath);
        } else {
          const response = await fetch(url!);
          if (!response.ok) {
            return err(`fetch ${url} returned HTTP ${response.status}`);
          }
          bytes = new Uint8Array(await response.arrayBuffer());
          if (!resolvedName) {
            const last = new URL(url!).pathname.split("/").filter(Boolean).pop();
            resolvedName = last ? decodeURIComponent(last) : "download";
          }
          if (!resolvedMime) {
            const ct = response.headers.get("content-type");
            if (ct) resolvedMime = ct.split(";")[0].trim();
          }
        }

        if (!resolvedMime) resolvedMime = inferMimeFromFileName(resolvedName!);
        if (!resolvedMime) {
          return err(
            `could not determine mime_type for ${resolvedName}; pass mime_type explicitly`,
          );
        }
        if (!ATTACHMENT_MIME_ALLOWLIST.has(resolvedMime)) {
          return err(
            `mime_type ${resolvedMime} is not in the attachments bucket allowlist`,
          );
        }
        if (bytes.length === 0) return err("file is empty");
        if (bytes.length > ATTACHMENT_MAX_BYTES) {
          return err(
            `file size ${bytes.length} bytes exceeds the 50MB limit`,
          );
        }

        const fileId = crypto.randomUUID();
        const storagePath = `${orgId}/${entity_type}/${entity_id}/${fileId}/${resolvedName}`;

        const { error: uploadErr } = await db.storage
          .from("attachments")
          .upload(storagePath, bytes, {
            contentType: resolvedMime,
            upsert: false,
          });
        if (uploadErr) return err(`storage upload failed: ${uploadErr.message}`);

        const { data: row, error: insertErr } = await db
          .from("attachments")
          .insert({
            entity_type,
            entity_id,
            org_id: orgId,
            uploaded_by: uploadedBy,
            file_name: resolvedName,
            file_size: bytes.length,
            mime_type: resolvedMime,
            storage_path: storagePath,
          })
          .select("*, uploader:users!uploaded_by(id, full_name, avatar_url)")
          .single();
        if (insertErr) {
          await db.storage.from("attachments").remove([storagePath]);
          return err(`insert failed: ${insertErr.message}`);
        }
        return json(row);
      } catch (e) {
        return err((e as Error).message);
      }
    },
  );

  server.tool(
    "trackr_attachment_list",
    "List non-deleted attachments for an entity.",
    {
      entity_type: z.enum(ATTACHMENT_ENTITY_TYPE),
      entity_id: z.string().uuid(),
    },
    async ({ entity_type, entity_id }) => {
      const { data, error } = await db
        .from("attachments")
        .select("*, uploader:users!uploaded_by(id, full_name, avatar_url)")
        .eq("entity_type", entity_type)
        .eq("entity_id", entity_id)
        .is("deleted_at", null)
        .order("created_at", { ascending: false });
      if (error) return err(error.message);
      return json(data);
    },
  );

  server.tool(
    "trackr_attachment_remove",
    "Soft-delete an attachment and remove the backing storage object. RLS allows this only for the uploader or users with tasks:delete in the org.",
    { id: z.string().uuid() },
    async ({ id }) => {
      const { data: row, error: selectErr } = await db
        .from("attachments")
        .select("storage_path")
        .eq("id", id)
        .is("deleted_at", null)
        .maybeSingle();
      if (selectErr) return err(selectErr.message);
      if (!row) return err(`attachment ${id} not found or already deleted`);
      const { error: updateErr } = await db
        .from("attachments")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", id);
      if (updateErr) return err(updateErr.message);
      await db.storage
        .from("attachments")
        .remove([row.storage_path as string]);
      return json({ id, deleted: true });
    },
  );
}
