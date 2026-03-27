-- Fix: soft-delete (UPDATE setting deleted_at) was blocked because PostgREST
-- also applies SELECT policies to the updated row. The SELECT policy requires
-- deleted_at IS NULL, so the newly soft-deleted row gets rejected.
--
-- Solution: use SECURITY DEFINER RPC functions for soft-delete that check
-- permissions internally, then bypass RLS for the actual UPDATE.

-- Restore UPDATE policies with WITH CHECK (true) for normal edits
DROP POLICY IF EXISTS wiki_folders_update ON public.wiki_folders;
CREATE POLICY wiki_folders_update ON public.wiki_folders
  FOR UPDATE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), id) = 'read_write'
  )
  WITH CHECK (true);

DROP POLICY IF EXISTS wiki_pages_update ON public.wiki_pages;
CREATE POLICY wiki_pages_update ON public.wiki_pages
  FOR UPDATE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_page(auth.uid(), id) = 'read_write'
  )
  WITH CHECK (true);

-- RPC: soft-delete a folder (bypasses RLS, checks permissions internally)
CREATE OR REPLACE FUNCTION public.wiki_soft_delete_folder(_folder_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
SET row_security = off
AS $$
BEGIN
  IF NOT (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), _folder_id) = 'read_write'
  ) THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.wiki_folders SET deleted_at = now() WHERE id = _folder_id AND deleted_at IS NULL;
END;
$$;

-- RPC: soft-delete a page (bypasses RLS, checks permissions internally)
CREATE OR REPLACE FUNCTION public.wiki_soft_delete_page(_page_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
SET row_security = off
AS $$
BEGIN
  IF NOT (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_page(auth.uid(), _page_id) = 'read_write'
  ) THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.wiki_pages SET deleted_at = now() WHERE id = _page_id AND deleted_at IS NULL;
END;
$$;
