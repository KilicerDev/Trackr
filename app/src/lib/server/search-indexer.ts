import { getAdminClient } from "$lib/server/supabase-admin";
import { extractText } from "$lib/server/extract-text";

export type DocumentPayload = {
  source_type: string;
  source_id: string;
  parent_id: string | null;
  org_id: string;
  title: string;
  preview: string | null;
  content: string;
  metadata: Record<string, unknown>;
};

type Admin = ReturnType<typeof getAdminClient>;

function truncate(s: string | null | undefined, max: number): string | null {
  if (!s) return null;
  return s.length > max ? s.slice(0, max) + "..." : s;
}

export async function buildPayload(
  sourceType: string,
  sourceId: string,
  admin: Admin
): Promise<DocumentPayload | null> {
  if (sourceType === "ticket") {
    const { data } = await admin
      .from("support_tickets")
      .select("id, subject, description, status, priority, channel, category, organization_id")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    return buildTicketPayload(data);
  }

  if (sourceType === "task") {
    const { data } = await admin
      .from("tasks")
      .select("id, title, description, status, priority, type, short_id, project_id, projects(name, color, organization_id)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    return buildTaskPayload(data);
  }

  if (sourceType === "ticket_message") {
    const { data } = await admin
      .from("support_ticket_messages")
      .select("id, body, is_internal_note, ticket_id, sender:users!sender_id(full_name), ticket:support_tickets!ticket_id(subject, organization_id)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    return buildTicketMessagePayload(data);
  }

  if (sourceType === "task_comment") {
    const { data } = await admin
      .from("task_comments")
      .select("id, content, task_id, task:tasks!task_id(title, short_id, project_id, projects(organization_id)), user:users!user_id(full_name)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    return buildTaskCommentPayload(data);
  }

  if (sourceType === "attachment") {
    const { data } = await admin
      .from("attachments")
      .select("id, file_name, mime_type, storage_path, entity_type, entity_id, org_id, uploader:users!uploaded_by(full_name)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    return buildAttachmentPayload(data, admin);
  }

  return null;
}

function buildTicketPayload(data: any): DocumentPayload {
  return {
    source_type: "ticket",
    source_id: data.id,
    parent_id: null,
    org_id: data.organization_id,
    title: data.subject,
    preview: truncate(data.description, 200),
    content: [data.subject, data.description].filter(Boolean).join(" "),
    metadata: {
      status: data.status,
      priority: data.priority,
      channel: data.channel,
      category: data.category,
    },
  };
}

function buildTaskPayload(data: any): DocumentPayload | null {
  const project = data.projects as { name: string; color: string | null; organization_id: string } | null;
  if (!project) return null;
  const displayTitle = data.short_id ? `${data.short_id}: ${data.title}` : data.title;
  return {
    source_type: "task",
    source_id: data.id,
    parent_id: data.project_id,
    org_id: project.organization_id,
    title: displayTitle,
    preview: truncate(data.description, 200),
    content: [data.title, data.description].filter(Boolean).join(" "),
    metadata: {
      status: data.status,
      priority: data.priority,
      type: data.type,
      short_id: data.short_id,
      project_id: data.project_id,
      project_name: project.name,
      project_color: project.color,
    },
  };
}

function buildTicketMessagePayload(data: any): DocumentPayload | null {
  const ticket = data.ticket as { subject: string; organization_id: string } | null;
  const sender = data.sender as { full_name: string } | null;
  if (!ticket) return null;
  return {
    source_type: "ticket_message",
    source_id: data.id,
    parent_id: data.ticket_id,
    org_id: ticket.organization_id,
    title: `Message in: ${ticket.subject}`,
    preview: truncate(data.body, 200),
    content: data.body,
    metadata: {
      ticket_id: data.ticket_id,
      ticket_subject: ticket.subject,
      sender_name: sender?.full_name ?? null,
      is_internal_note: data.is_internal_note,
    },
  };
}

function buildTaskCommentPayload(data: any): DocumentPayload | null {
  const task = data.task as { title: string; short_id: string | null; project_id: string; projects: { organization_id: string } } | null;
  const user = data.user as { full_name: string } | null;
  if (!task) return null;
  const label = task.short_id ? `Comment on: ${task.short_id}` : `Comment on: ${task.title}`;
  return {
    source_type: "task_comment",
    source_id: data.id,
    parent_id: data.task_id,
    org_id: task.projects.organization_id,
    title: label,
    preview: truncate(data.content, 200),
    content: data.content,
    metadata: {
      task_id: data.task_id,
      task_short_id: task.short_id,
      task_title: task.title,
      project_id: task.project_id,
      user_name: user?.full_name ?? null,
    },
  };
}

async function resolveAttachmentProjectId(
  entityType: string,
  entityId: string,
  admin: Admin
): Promise<string | null> {
  if (entityType === "project") return entityId;
  if (entityType === "task") {
    const { data } = await admin
      .from("tasks")
      .select("project_id")
      .eq("id", entityId)
      .single();
    return (data?.project_id as string | undefined) ?? null;
  }
  if (entityType === "task_comment") {
    const { data } = await admin
      .from("task_comments")
      .select("task:tasks!task_id(project_id)")
      .eq("id", entityId)
      .single();
    const task = (data?.task as unknown) as { project_id: string } | null;
    return task?.project_id ?? null;
  }
  return null;
}

async function buildAttachmentPayload(data: any, admin: Admin): Promise<DocumentPayload> {
  const uploader = data.uploader as { full_name: string } | null;
  let extractedText: string | null = null;
  try {
    extractedText = await extractText(data.storage_path, data.mime_type);
  } catch {
    // text extraction is best-effort
  }
  const content = [data.file_name, extractedText].filter(Boolean).join(" ");
  const projectId = await resolveAttachmentProjectId(data.entity_type, data.entity_id, admin);
  return {
    source_type: "attachment",
    source_id: data.id,
    parent_id: data.entity_id,
    org_id: data.org_id,
    title: data.file_name,
    preview: truncate(extractedText, 200),
    content,
    metadata: {
      file_name: data.file_name,
      mime_type: data.mime_type,
      entity_type: data.entity_type,
      entity_id: data.entity_id,
      uploader_name: uploader?.full_name ?? null,
      project_id: projectId,
    },
  };
}

export type ReindexCounts = {
  ticket: number;
  task: number;
  ticket_message: number;
  task_comment: number;
  attachment: number;
};

export async function reindexOrganization(
  orgId: string,
  admin: Admin
): Promise<ReindexCounts> {
  const counts: ReindexCounts = {
    ticket: 0,
    task: 0,
    ticket_message: 0,
    task_comment: 0,
    attachment: 0,
  };

  const upsert = async (payloads: DocumentPayload[]) => {
    if (payloads.length === 0) return;
    const { error: upsertError } = await admin
      .from("search_documents")
      .upsert(payloads, { onConflict: "source_type,source_id" });
    if (upsertError) throw new Error(upsertError.message);
  };

  const { data: tickets } = await admin
    .from("support_tickets")
    .select("id, subject, description, status, priority, channel, category, organization_id")
    .eq("organization_id", orgId)
    .is("deleted_at", null);
  const ticketIds = (tickets ?? []).map((t) => t.id);
  if (tickets && tickets.length) {
    const payloads = tickets.map(buildTicketPayload);
    await upsert(payloads);
    counts.ticket = payloads.length;
  }

  if (ticketIds.length) {
    const { data: ticketMessages } = await admin
      .from("support_ticket_messages")
      .select("id, body, is_internal_note, ticket_id, sender:users!sender_id(full_name), ticket:support_tickets!ticket_id(subject, organization_id)")
      .in("ticket_id", ticketIds)
      .is("deleted_at", null);
    if (ticketMessages) {
      const payloads = ticketMessages
        .map((r) => buildTicketMessagePayload(r))
        .filter((p): p is DocumentPayload => p !== null);
      await upsert(payloads);
      counts.ticket_message = payloads.length;
    }
  }

  const { data: projects } = await admin
    .from("projects")
    .select("id")
    .eq("organization_id", orgId);
  const projectIds = (projects ?? []).map((p) => p.id);

  let taskIds: string[] = [];
  if (projectIds.length) {
    const { data: tasks } = await admin
      .from("tasks")
      .select("id, title, description, status, priority, type, short_id, project_id, projects(name, color, organization_id)")
      .in("project_id", projectIds)
      .is("deleted_at", null);
    if (tasks) {
      taskIds = tasks.map((t) => t.id);
      const payloads = tasks
        .map((r) => buildTaskPayload(r))
        .filter((p): p is DocumentPayload => p !== null);
      await upsert(payloads);
      counts.task = payloads.length;
    }
  }

  if (taskIds.length) {
    const { data: taskComments } = await admin
      .from("task_comments")
      .select("id, content, task_id, task:tasks!task_id(title, short_id, project_id, projects(organization_id)), user:users!user_id(full_name)")
      .in("task_id", taskIds)
      .is("deleted_at", null);
    if (taskComments) {
      const payloads = taskComments
        .map((r) => buildTaskCommentPayload(r))
        .filter((p): p is DocumentPayload => p !== null);
      await upsert(payloads);
      counts.task_comment = payloads.length;
    }
  }

  const { data: attachments } = await admin
    .from("attachments")
    .select("id, file_name, mime_type, storage_path, entity_type, entity_id, org_id, uploader:users!uploaded_by(full_name)")
    .eq("org_id", orgId)
    .is("deleted_at", null);
  if (attachments && attachments.length) {
    const payloads: DocumentPayload[] = [];
    for (const row of attachments) {
      payloads.push(await buildAttachmentPayload(row, admin));
    }
    await upsert(payloads);
    counts.attachment = payloads.length;
  }

  return counts;
}
