-- ============================================
-- WIKI: folders and pages for the Knowledge Base wiki
-- ============================================

-- 1. wiki_folders — hierarchical folder structure
CREATE TABLE public.wiki_folders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  parent_id       uuid REFERENCES public.wiki_folders(id) ON DELETE CASCADE,
  name            text NOT NULL,
  position        int  NOT NULL DEFAULT 0,
  created_by      uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

-- 2. wiki_pages — wiki page content
CREATE TABLE public.wiki_pages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  folder_id       uuid REFERENCES public.wiki_folders(id) ON DELETE SET NULL,
  title           text NOT NULL DEFAULT 'Untitled',
  content         text NOT NULL DEFAULT '',
  position        int  NOT NULL DEFAULT 0,
  icon            text,
  created_by      uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  updated_by      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

-- 3. Indexes
CREATE INDEX idx_wiki_folders_org    ON public.wiki_folders (organization_id)        WHERE deleted_at IS NULL;
CREATE INDEX idx_wiki_folders_parent ON public.wiki_folders (parent_id, position)     WHERE deleted_at IS NULL;
CREATE INDEX idx_wiki_pages_org      ON public.wiki_pages   (organization_id)        WHERE deleted_at IS NULL;
CREATE INDEX idx_wiki_pages_folder   ON public.wiki_pages   (folder_id, position)    WHERE deleted_at IS NULL;

-- 4. Triggers — reuse existing handle_updated_at()
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.wiki_folders FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.wiki_pages   FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 5. RLS
ALTER TABLE public.wiki_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wiki_pages   ENABLE ROW LEVEL SECURITY;

-- wiki_folders policies
CREATE POLICY wiki_folders_select ON public.wiki_folders
  FOR SELECT USING (
    deleted_at IS NULL
    AND public.is_member_of(organization_id)
  );

CREATE POLICY wiki_folders_insert ON public.wiki_folders
  FOR INSERT WITH CHECK (
    public.is_member_of(organization_id)
    AND created_by = auth.uid()
  );

CREATE POLICY wiki_folders_update ON public.wiki_folders
  FOR UPDATE USING (
    public.is_member_of(organization_id)
  );

CREATE POLICY wiki_folders_delete ON public.wiki_folders
  FOR DELETE USING (
    public.is_member_of(organization_id)
  );

-- wiki_pages policies
CREATE POLICY wiki_pages_select ON public.wiki_pages
  FOR SELECT USING (
    deleted_at IS NULL
    AND public.is_member_of(organization_id)
  );

CREATE POLICY wiki_pages_insert ON public.wiki_pages
  FOR INSERT WITH CHECK (
    public.is_member_of(organization_id)
    AND created_by = auth.uid()
  );

CREATE POLICY wiki_pages_update ON public.wiki_pages
  FOR UPDATE USING (
    public.is_member_of(organization_id)
  );

CREATE POLICY wiki_pages_delete ON public.wiki_pages
  FOR DELETE USING (
    public.is_member_of(organization_id)
  );
