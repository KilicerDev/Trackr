-- ============================================
-- PROJECT-SCOPED TAGS: colored labels for tasks (many-to-many)
-- ============================================

-- 1. Tags table (scoped per project)
CREATE TABLE public.tags (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#6366f1',
  created_by  uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (project_id, name)
);

-- 2. Junction table
CREATE TABLE public.task_tags (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id    uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  tag_id     uuid NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  UNIQUE (task_id, tag_id)
);

-- 3. Indexes
CREATE INDEX idx_tags_project_id  ON public.tags (project_id);
CREATE INDEX idx_tags_created_by  ON public.tags (created_by);
CREATE INDEX idx_task_tags_task_id ON public.task_tags (task_id);
CREATE INDEX idx_task_tags_tag_id  ON public.task_tags (tag_id);

-- 4. updated_at trigger (reuse existing function)
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.tags
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 5. RLS — tags (mirrors tasks policies)
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tags_select" ON public.tags
  FOR SELECT TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.project_org_id(project_id),
      false
    )
    OR public.is_project_member(project_id)
  );

CREATE POLICY "tags_insert" ON public.tags
  FOR INSERT TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'create', public.project_org_id(project_id))
    OR public.is_project_member(project_id)
  );

CREATE POLICY "tags_update" ON public.tags
  FOR UPDATE TO authenticated
  USING (
    public.authorize(
      'tasks', 'update',
      public.project_org_id(project_id),
      created_by = auth.uid()
    )
    OR public.is_project_member(project_id)
  );

CREATE POLICY "tags_delete" ON public.tags
  FOR DELETE TO authenticated
  USING (
    public.authorize(
      'tasks', 'update',
      public.project_org_id(project_id),
      created_by = auth.uid()
    )
    OR public.is_project_member(project_id)
  );

-- 6. RLS — task_tags (mirrors task_assignments policies)
ALTER TABLE public.task_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_tags_select" ON public.task_tags
  FOR SELECT TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      false
    )
    OR public.is_project_member_via_task(task_id)
  );

CREATE POLICY "task_tags_insert" ON public.task_tags
  FOR INSERT TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'update', public.task_org_id(task_id))
    OR public.is_project_member_via_task(task_id)
  );

CREATE POLICY "task_tags_delete" ON public.task_tags
  FOR DELETE TO authenticated
  USING (
    public.authorize('tasks', 'update', public.task_org_id(task_id))
    OR public.is_project_member_via_task(task_id)
  );
