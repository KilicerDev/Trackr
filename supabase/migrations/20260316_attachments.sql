-- ============================================
-- ATTACHMENTS: file attachments for tasks, tickets, projects, comments/messages
-- ============================================

-- 1. Enum for entity types
CREATE TYPE public.attachment_entity_type AS ENUM (
  'task', 'task_comment', 'support_ticket', 'ticket_message', 'project'
);

-- 2. Attachments table
CREATE TABLE public.attachments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type public.attachment_entity_type NOT NULL,
  entity_id   uuid NOT NULL,
  org_id      uuid NOT NULL REFERENCES public.organizations(id),
  uploaded_by uuid NOT NULL REFERENCES public.users(id),
  file_name   text NOT NULL,
  file_size   bigint NOT NULL CHECK (file_size > 0 AND file_size <= 52428800),
  mime_type   text NOT NULL,
  storage_path text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

-- 3. Indexes
CREATE INDEX idx_attachments_entity ON public.attachments (entity_type, entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_attachments_org    ON public.attachments (org_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_attachments_uploader ON public.attachments (uploaded_by) WHERE deleted_at IS NULL;

-- 4. RLS
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY attachments_select ON public.attachments
  FOR SELECT USING (
    deleted_at IS NULL
    AND public.is_member_of(org_id)
  );

CREATE POLICY attachments_insert ON public.attachments
  FOR INSERT WITH CHECK (
    public.is_member_of(org_id)
    AND uploaded_by = auth.uid()
  );

CREATE POLICY attachments_delete ON public.attachments
  FOR UPDATE USING (
    uploaded_by = auth.uid()
    OR public.authorize('tasks', 'delete', org_id)
  );

-- 5. Storage bucket is created via supabase/config.toml [storage.buckets.attachments]

-- 6. Add attachment_ids column to comments and messages
ALTER TABLE public.task_comments ADD COLUMN attachment_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.support_ticket_messages ADD COLUMN attachment_ids uuid[] NOT NULL DEFAULT '{}';

-- 7. Storage RLS policies
CREATE POLICY storage_attachments_select ON storage.objects
  FOR SELECT USING (
    bucket_id = 'attachments'
    AND public.is_member_of((string_to_array(name, '/'))[1]::uuid)
  );

CREATE POLICY storage_attachments_insert ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'attachments'
    AND public.is_member_of((string_to_array(name, '/'))[1]::uuid)
  );

CREATE POLICY storage_attachments_delete ON storage.objects
  FOR DELETE USING (
    bucket_id = 'attachments'
    AND public.is_member_of((string_to_array(name, '/'))[1]::uuid)
  );
