-- Wiki file uploads: stores file metadata for files uploaded to wiki folders.
-- Actual file content lives in the existing "attachments" Supabase Storage bucket.

CREATE TABLE public.wiki_files (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  folder_id       uuid NOT NULL REFERENCES public.wiki_folders(id) ON DELETE CASCADE,
  file_name       text NOT NULL,
  file_size       bigint NOT NULL CHECK (file_size > 0 AND file_size <= 52428800),
  mime_type       text NOT NULL,
  storage_path    text NOT NULL,
  position        int  NOT NULL DEFAULT 0,
  uploaded_by     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

-- Indexes
CREATE INDEX idx_wiki_files_org    ON public.wiki_files (organization_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_wiki_files_folder ON public.wiki_files (folder_id, position) WHERE deleted_at IS NULL;

-- Auto-update updated_at
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.wiki_files
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.wiki_files ENABLE ROW LEVEL SECURITY;

-- SELECT: admins or users with any access level on the parent folder
CREATE POLICY wiki_files_select ON public.wiki_files
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      public.is_wiki_admin()
      OR public.wiki_user_access_level_for_folder(auth.uid(), folder_id) IS NOT NULL
    )
  );

-- INSERT: admins or users with read_write access on the target folder
CREATE POLICY wiki_files_insert ON public.wiki_files
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND (
      public.is_wiki_admin()
      OR public.wiki_user_access_level_for_folder(auth.uid(), folder_id) = 'read_write'
    )
  );

-- UPDATE: admins or read_write on folder (WITH CHECK true for soft-delete pattern)
CREATE POLICY wiki_files_update ON public.wiki_files
  FOR UPDATE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), folder_id) = 'read_write'
  )
  WITH CHECK (true);

-- DELETE: admins or read_write on folder
CREATE POLICY wiki_files_delete ON public.wiki_files
  FOR DELETE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), folder_id) = 'read_write'
  );

-- RPC: soft-delete a file (bypasses RLS, checks permissions internally)
CREATE OR REPLACE FUNCTION public.wiki_soft_delete_file(_file_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
SET row_security = off
AS $$
DECLARE
  _folder_id uuid;
BEGIN
  SELECT wf.folder_id INTO _folder_id
  FROM public.wiki_files wf
  WHERE wf.id = _file_id AND wf.deleted_at IS NULL;

  IF _folder_id IS NULL THEN
    RAISE EXCEPTION 'File not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), _folder_id) = 'read_write'
  ) THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.wiki_files SET deleted_at = now() WHERE id = _file_id AND deleted_at IS NULL;
END;
$$;
