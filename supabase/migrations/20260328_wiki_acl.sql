-- ============================================
-- WIKI ACL: granular access control for wiki folders and pages
--
-- Default: no access for anyone except platform org admins/owners.
-- Access is granted per-user on folders (cascading to children) or pages.
-- Two levels: 'read' (view only) and 'read_write' (view + edit + create inside).
-- ============================================

-- 1. Access level enum
CREATE TYPE public.wiki_access_level AS ENUM ('read', 'read_write');

-- 2. Access grants table
CREATE TABLE public.wiki_access (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  folder_id       uuid REFERENCES public.wiki_folders(id) ON DELETE CASCADE,
  page_id         uuid REFERENCES public.wiki_pages(id) ON DELETE CASCADE,
  access_level    public.wiki_access_level NOT NULL DEFAULT 'read',
  granted_by      uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at      timestamptz NOT NULL DEFAULT now(),

  -- Exactly one of folder_id or page_id must be set
  CONSTRAINT wiki_access_target_check CHECK (
    (folder_id IS NOT NULL AND page_id IS NULL)
    OR (folder_id IS NULL AND page_id IS NOT NULL)
  )
);

-- 3. Indexes (partial unique indexes enforce one grant per user per target)
CREATE UNIQUE INDEX idx_wiki_access_user_folder ON public.wiki_access (user_id, folder_id) WHERE folder_id IS NOT NULL;
CREATE UNIQUE INDEX idx_wiki_access_user_page   ON public.wiki_access (user_id, page_id)   WHERE page_id IS NOT NULL;
CREATE INDEX idx_wiki_access_org_user           ON public.wiki_access (organization_id, user_id);

-- 4. Helper: is current user a wiki admin (platform org admin or owner)?
CREATE OR REPLACE FUNCTION public.is_wiki_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
SET row_security = off
AS $$
DECLARE
  _platform_org_id uuid;
  _role_slug text;
BEGIN
  SELECT sc.platform_organization_id INTO _platform_org_id
  FROM public.system_config sc LIMIT 1;

  IF _platform_org_id IS NULL THEN RETURN false; END IF;

  SELECT r.slug INTO _role_slug
  FROM public.organization_members om
  JOIN public.roles r ON r.id = om.role_id
  WHERE om.organization_id = _platform_org_id
    AND om.user_id = auth.uid()
    AND r.is_system = true;

  RETURN _role_slug IN ('owner', 'admin');
END;
$$;

-- 5. Helper: effective access level for a user on a folder (walks parent chain)
CREATE OR REPLACE FUNCTION public.wiki_user_access_level_for_folder(
  _user_id   uuid,
  _folder_id uuid
)
RETURNS public.wiki_access_level
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
SET row_security = off
AS $$
DECLARE
  _current_id uuid := _folder_id;
  _level      public.wiki_access_level := NULL;
  _grant      public.wiki_access_level;
  _depth      int := 0;
BEGIN
  WHILE _current_id IS NOT NULL AND _depth < 10 LOOP
    SELECT wa.access_level INTO _grant
    FROM public.wiki_access wa
    WHERE wa.user_id = _user_id
      AND wa.folder_id = _current_id;

    IF _grant IS NOT NULL THEN
      IF _grant = 'read_write' THEN RETURN 'read_write'; END IF;
      IF _level IS NULL THEN _level := _grant; END IF;
    END IF;

    SELECT wf.parent_id INTO _current_id
    FROM public.wiki_folders wf
    WHERE wf.id = _current_id;

    _depth := _depth + 1;
  END LOOP;

  RETURN _level;
END;
$$;

-- 6. Helper: effective access level for a user on a page (direct + inherited from folder chain)
CREATE OR REPLACE FUNCTION public.wiki_user_access_level_for_page(
  _user_id uuid,
  _page_id uuid
)
RETURNS public.wiki_access_level
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
SET row_security = off
AS $$
DECLARE
  _page_folder_id uuid;
  _page_grant     public.wiki_access_level;
  _folder_grant   public.wiki_access_level;
BEGIN
  -- Direct page-level grant
  SELECT wa.access_level INTO _page_grant
  FROM public.wiki_access wa
  WHERE wa.user_id = _user_id
    AND wa.page_id = _page_id;

  IF _page_grant = 'read_write' THEN RETURN 'read_write'; END IF;

  -- Inherited from folder chain
  SELECT wp.folder_id INTO _page_folder_id
  FROM public.wiki_pages wp
  WHERE wp.id = _page_id;

  IF _page_folder_id IS NOT NULL THEN
    _folder_grant := public.wiki_user_access_level_for_folder(_user_id, _page_folder_id);
  END IF;

  -- Most permissive wins
  IF _folder_grant = 'read_write' OR _page_grant = 'read_write' THEN RETURN 'read_write'; END IF;
  IF _folder_grant IS NOT NULL OR _page_grant IS NOT NULL THEN RETURN 'read'; END IF;

  RETURN NULL;
END;
$$;

-- 7. Drop old wiki RLS policies
DROP POLICY IF EXISTS wiki_folders_select ON public.wiki_folders;
DROP POLICY IF EXISTS wiki_folders_insert ON public.wiki_folders;
DROP POLICY IF EXISTS wiki_folders_update ON public.wiki_folders;
DROP POLICY IF EXISTS wiki_folders_delete ON public.wiki_folders;

DROP POLICY IF EXISTS wiki_pages_select ON public.wiki_pages;
DROP POLICY IF EXISTS wiki_pages_insert ON public.wiki_pages;
DROP POLICY IF EXISTS wiki_pages_update ON public.wiki_pages;
DROP POLICY IF EXISTS wiki_pages_delete ON public.wiki_pages;

-- 8. New wiki_folders policies
CREATE POLICY wiki_folders_select ON public.wiki_folders
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      public.is_wiki_admin()
      OR public.wiki_user_access_level_for_folder(auth.uid(), id) IS NOT NULL
    )
  );

CREATE POLICY wiki_folders_insert ON public.wiki_folders
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND (
      public.is_wiki_admin()
      OR (
        parent_id IS NOT NULL
        AND public.wiki_user_access_level_for_folder(auth.uid(), parent_id) = 'read_write'
      )
    )
  );

CREATE POLICY wiki_folders_update ON public.wiki_folders
  FOR UPDATE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), id) = 'read_write'
  );

CREATE POLICY wiki_folders_delete ON public.wiki_folders
  FOR DELETE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_folder(auth.uid(), id) = 'read_write'
  );

-- 9. New wiki_pages policies
CREATE POLICY wiki_pages_select ON public.wiki_pages
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      public.is_wiki_admin()
      OR public.wiki_user_access_level_for_page(auth.uid(), id) IS NOT NULL
    )
  );

CREATE POLICY wiki_pages_insert ON public.wiki_pages
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND (
      public.is_wiki_admin()
      OR (
        folder_id IS NOT NULL
        AND public.wiki_user_access_level_for_folder(auth.uid(), folder_id) = 'read_write'
      )
    )
  );

CREATE POLICY wiki_pages_update ON public.wiki_pages
  FOR UPDATE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_page(auth.uid(), id) = 'read_write'
  );

CREATE POLICY wiki_pages_delete ON public.wiki_pages
  FOR DELETE TO authenticated
  USING (
    public.is_wiki_admin()
    OR public.wiki_user_access_level_for_page(auth.uid(), id) = 'read_write'
  );

-- 10. wiki_access table RLS
ALTER TABLE public.wiki_access ENABLE ROW LEVEL SECURITY;

CREATE POLICY wiki_access_select ON public.wiki_access
  FOR SELECT TO authenticated
  USING (
    public.is_wiki_admin()
    OR user_id = auth.uid()
  );

CREATE POLICY wiki_access_insert ON public.wiki_access
  FOR INSERT TO authenticated
  WITH CHECK (public.is_wiki_admin());

CREATE POLICY wiki_access_update ON public.wiki_access
  FOR UPDATE TO authenticated
  USING (public.is_wiki_admin());

CREATE POLICY wiki_access_delete ON public.wiki_access
  FOR DELETE TO authenticated
  USING (public.is_wiki_admin());
