import { getClient } from "./client";
import { ATTACHMENT_SELECT } from "./queries";
import { indexDocument } from "./search-index";

export type AttachmentEntityType = 'task' | 'task_comment' | 'support_ticket' | 'ticket_message' | 'project';

export type Attachment = {
  id: string;
  entity_type: AttachmentEntityType;
  entity_id: string;
  org_id: string;
  uploaded_by: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  storage_path: string;
  created_at: string;
  deleted_at: string | null;
  uploader?: { id: string; full_name: string; avatar_url: string | null } | null;
};

export const attachments = {
  async list(entityType: AttachmentEntityType, entityId: string): Promise<Attachment[]> {
    const supabase = getClient();
    const { data, error } = await supabase
      .from("attachments")
      .select(ATTACHMENT_SELECT)
      .eq("entity_type", entityType)
      .eq("entity_id", entityId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false });

    if (error) throw error;
    return (data ?? []) as Attachment[];
  },

  async listForEntityAndChildren(
    entityType: AttachmentEntityType,
    entityId: string,
    childType: AttachmentEntityType,
    childIds: string[]
  ): Promise<Attachment[]> {
    const supabase = getClient();
    const allIds = [entityId, ...childIds];
    const types = [entityType, childType];

    const { data, error } = await supabase
      .from("attachments")
      .select(ATTACHMENT_SELECT)
      .in("entity_type", types)
      .in("entity_id", allIds)
      .is("deleted_at", null)
      .order("created_at", { ascending: false });

    if (error) throw error;
    return (data ?? []) as Attachment[];
  },

  async upload(
    file: File,
    entityType: AttachmentEntityType,
    entityId: string,
    orgId: string,
    uploadedBy: string
  ): Promise<Attachment> {
    const supabase = getClient();
    const fileId = crypto.randomUUID();
    const storagePath = `${orgId}/${entityType}/${entityId}/${fileId}/${file.name}`;

    const { error: uploadError } = await supabase.storage
      .from("attachments")
      .upload(storagePath, file, {
        contentType: file.type,
        upsert: false,
      });

    if (uploadError) throw uploadError;

    const { data, error: insertError } = await supabase
      .from("attachments")
      .insert({
        entity_type: entityType,
        entity_id: entityId,
        org_id: orgId,
        uploaded_by: uploadedBy,
        file_name: file.name,
        file_size: file.size,
        mime_type: file.type,
        storage_path: storagePath,
      })
      .select(ATTACHMENT_SELECT)
      .single();

    if (insertError) {
      // Clean up uploaded file if DB insert fails
      await supabase.storage.from("attachments").remove([storagePath]);
      throw insertError;
    }

    indexDocument("attachment", data.id);
    return data as Attachment;
  },

  async remove(id: string, storagePath: string): Promise<void> {
    const supabase = getClient();

    const { error: dbError } = await supabase
      .from("attachments")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", id);

    if (dbError) throw dbError;

    await supabase.storage.from("attachments").remove([storagePath]);
  },

  async getSignedUrl(storagePath: string): Promise<string> {
    const supabase = getClient();
    const { data, error } = await supabase.storage
      .from("attachments")
      .createSignedUrl(storagePath, 3600); // 1 hour

    if (error) throw error;
    return data.signedUrl;
  },

  async getThumbnailUrl(storagePath: string, width = 200, height = 200): Promise<string> {
    const supabase = getClient();
    const { data, error } = await supabase.storage
      .from("attachments")
      .createSignedUrl(storagePath, 3600, {
        transform: { width, height, resize: "cover" },
      });

    if (error) throw error;
    return data.signedUrl;
  },
};
