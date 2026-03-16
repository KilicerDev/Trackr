import { json, error } from "@sveltejs/kit";
import { env } from "$env/dynamic/private";
import { getAdminClient } from "$lib/server/supabase-admin";
import { extractText } from "$lib/server/extract-text";
import type { RequestHandler } from "./$types";

type DocumentPayload = {
  source_type: string;
  source_id: string;
  parent_id: string | null;
  org_id: string;
  title: string;
  preview: string | null;
  content: string;
  metadata: Record<string, unknown>;
};

function truncate(s: string | null | undefined, max: number): string | null {
  if (!s) return null;
  return s.length > max ? s.slice(0, max) + "..." : s;
}

async function buildPayload(
  sourceType: string,
  sourceId: string,
  admin: ReturnType<typeof getAdminClient>
): Promise<DocumentPayload | null> {
  if (sourceType === "ticket") {
    const { data } = await admin
      .from("support_tickets")
      .select("id, subject, description, status, priority, channel, category, organization_id")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
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

  if (sourceType === "task") {
    const { data } = await admin
      .from("tasks")
      .select("id, title, description, status, priority, type, short_id, project_id, projects(name, color, organization_id)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    const project = data.projects as unknown as { name: string; color: string | null; organization_id: string } | null;
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

  if (sourceType === "ticket_message") {
    const { data } = await admin
      .from("support_ticket_messages")
      .select("id, body, is_internal_note, ticket_id, sender:users!sender_id(full_name), ticket:support_tickets!ticket_id(subject, organization_id)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    const ticket = data.ticket as unknown as { subject: string; organization_id: string } | null;
    const sender = data.sender as unknown as { full_name: string } | null;
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

  if (sourceType === "task_comment") {
    const { data } = await admin
      .from("task_comments")
      .select("id, content, task_id, task:tasks!task_id(title, short_id, project_id, projects(organization_id)), user:users!user_id(full_name)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    const task = data.task as unknown as { title: string; short_id: string | null; project_id: string; projects: { organization_id: string } } | null;
    const user = data.user as unknown as { full_name: string } | null;
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

  if (sourceType === "attachment") {
    const { data } = await admin
      .from("attachments")
      .select("id, file_name, mime_type, storage_path, entity_type, entity_id, org_id, uploader:users!uploaded_by(full_name)")
      .eq("id", sourceId)
      .is("deleted_at", null)
      .single();
    if (!data) return null;
    const uploader = data.uploader as unknown as { full_name: string } | null;
    let extractedText: string | null = null;
    try {
      extractedText = await extractText(data.storage_path, data.mime_type);
    } catch {
      // text extraction is best-effort
    }
    const content = [data.file_name, extractedText].filter(Boolean).join(" ");
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
      },
    };
  }

  return null;
}

export const POST: RequestHandler = async ({ request, locals }) => {
  if (!locals.session) throw error(401, "Not authenticated");

  const { source_type, source_id } = await request.json();
  if (!source_type || !source_id) {
    throw error(400, "source_type and source_id are required");
  }

  const embedUrl = env.EMBED_SERVICE_URL;
  const embedToken = env.EMBED_SERVICE_TOKEN;
  if (!embedUrl || !embedToken) {
    throw error(503, "Search service not configured");
  }

  const admin = getAdminClient();
  const payload = await buildPayload(source_type, source_id, admin);
  if (!payload) {
    return json({ status: "skipped", reason: "record not found" });
  }

  // Fire-and-forget: don't await, just log errors
  fetch(`${embedUrl}/index`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${embedToken}`,
    },
    body: JSON.stringify(payload),
  }).catch((err) => {
    console.error("embed-service /index error:", err);
  });

  return json({ status: "indexing" });
};
