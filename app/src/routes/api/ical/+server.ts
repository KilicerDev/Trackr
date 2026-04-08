import { error, json } from "@sveltejs/kit";
import { getAdminClient } from "$lib/server/supabase-admin";
import { sha256, generateIcal, type IcalTask, type IcalTicket } from "$lib/server/ical";
import type { RequestHandler } from "@sveltejs/kit";

const RATE_LIMIT_MS = 30_000; // 30 seconds between requests per token
const COMPLETED_CUTOFF_DAYS = 30; // only include completed items from last 30 days

/**
 * GET /api/ical?token=<secret>[&project=<id>][&type=tasks|tickets]
 *
 * Returns an iCal (.ics) feed of tasks/tickets assigned to the token owner.
 * Authentication is via the secret token in the query string (not session cookies).
 */
export const GET: RequestHandler = async ({ url }) => {
  // 1. Extract and validate token
  const token = url.searchParams.get("token");
  if (!token) throw error(401, "Missing token");

  const tokenHash = await sha256(token);
  const admin = getAdminClient();

  // 2. Look up token (admin client bypasses RLS)
  const { data: tokenRow } = await admin
    .from("ical_tokens")
    .select("id, user_id, last_used_at")
    .eq("token_hash", tokenHash)
    .is("revoked_at", null)
    .single();

  if (!tokenRow) throw error(401, "Invalid or revoked token");

  // 3. Rate limit
  if (tokenRow.last_used_at) {
    const elapsed = Date.now() - new Date(tokenRow.last_used_at).getTime();
    if (elapsed < RATE_LIMIT_MS) {
      throw error(429, "Too many requests");
    }
  }

  // 4. Update last_used_at (fire-and-forget)
  admin
    .from("ical_tokens")
    .update({ last_used_at: new Date().toISOString() })
    .eq("id", tokenRow.id)
    .then(() => {});

  // 5. Parse filter params
  const projectId = url.searchParams.get("project");
  const type = url.searchParams.get("type"); // 'tasks' | 'tickets' | null

  const userId = tokenRow.user_id;
  const cutoffDate = new Date(Date.now() - COMPLETED_CUTOFF_DAYS * 86400000).toISOString();

  let tasks: IcalTask[] = [];
  let tickets: IcalTicket[] = [];
  let projectName: string | null = null;

  // 6. Fetch tasks assigned to user
  if (!type || type === "tasks") {
    // First get task IDs assigned to this user
    const { data: assignments } = await admin
      .from("task_assignments")
      .select("task_id")
      .eq("user_id", userId);

    const taskIds = (assignments ?? []).map((a) => a.task_id);

    if (taskIds.length > 0) {
      let q = admin
        .from("tasks")
        .select(
          "id, title, description, status, priority, type, start_at, end_at, updated_at, created_at, project:projects(id, name)"
        )
        .is("deleted_at", null)
        .in("id", taskIds);

      if (projectId) q = q.eq("project_id", projectId);

      // Exclude old completed/cancelled items
      // We want: active items OR completed items within cutoff
      // Supabase doesn't support OR easily, so fetch all and filter in JS
      const { data } = await q.order("created_at", { ascending: false }).limit(500);

      const filtered = (data ?? []).filter((t: Record<string, unknown>) => {
        const isCompleted = t.status === "done" || t.status === "cancelled";
        if (!isCompleted) return true;
        return (t.updated_at as string) >= cutoffDate;
      });

      // Supabase returns FK joins as arrays; normalize to single object
      tasks = filtered.map((t: Record<string, unknown>) => {
        const proj = Array.isArray(t.project) ? t.project[0] : t.project;
        return { ...t, project: proj ?? null } as unknown as IcalTask;
      });

      // Get project name from first task if filtering by project
      if (projectId && tasks.length > 0 && tasks[0].project) {
        projectName = tasks[0].project.name;
      }
    }
  }

  // 7. Fetch tickets assigned to user
  if (!type || type === "tickets") {
    let q = admin
      .from("support_tickets")
      .select("id, subject, description, status, priority, sla_deadline, updated_at, created_at")
      .is("deleted_at", null)
      .eq("assigned_agent_id", userId);

    const { data } = await q.order("created_at", { ascending: false }).limit(500);

    tickets = (data ?? []).filter((t: Record<string, unknown>) => {
      const isCompleted = t.status === "resolved" || t.status === "closed";
      if (!isCompleted) return true;
      return (t.updated_at as string) >= cutoffDate;
    }) as unknown as IcalTicket[];
  }

  // 8. JSON format — flat, Shortcuts-friendly response
  const format = url.searchParams.get("format");

  if (format === "json") {
    const jsonTasks = tasks.map((t) => ({
      id: t.id,
      title: t.title,
      description: t.description ?? null,
      status: t.status,
      priority: t.priority,
      type: t.type ?? null,
      due: t.end_at ?? null,
      start: t.start_at ?? null,
      project: t.project?.name ?? null,
      created_at: t.created_at,
    }));

    const jsonTickets = tickets.map((t) => ({
      id: t.id,
      title: t.subject,
      description: t.description ?? null,
      status: t.status,
      priority: t.priority,
      due: t.sla_deadline ?? null,
      created_at: t.created_at,
    }));

    return json({ tasks: jsonTasks, tickets: jsonTickets });
  }

  // 9. Build calendar name
  let calName = "Trackr";
  if (projectName) calName = `Trackr - ${projectName}`;
  if (type === "tasks") calName += " Tasks";
  else if (type === "tickets") calName += " Tickets";

  // 10. If filtering by project but no tasks found yet, try to get project name
  if (projectId && !projectName) {
    const { data: proj } = await admin
      .from("projects")
      .select("name")
      .eq("id", projectId)
      .single();
    if (proj) calName = `Trackr - ${proj.name}`;
    if (type === "tasks") calName += " Tasks";
    else if (type === "tickets") calName += " Tickets";
  }

  // 11. Generate iCal
  const ical = generateIcal({
    calendarName: calName,
    tasks,
    tickets,
  });

  return new Response(ical, {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'inline; filename="trackr.ics"',
      "Cache-Control": "no-cache, no-store, must-revalidate",
    },
  });
};
