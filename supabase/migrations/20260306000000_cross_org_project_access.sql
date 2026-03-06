-- ============================================
-- MIGRATION: Cross-org project access via project_members
--
-- Allow users assigned to a project (via project_members) to access
-- that project, its tasks, and its members WITHOUT requiring
-- membership in the project's organization.
--
-- Uses SECURITY DEFINER helpers to avoid RLS circular dependencies.
-- ============================================


-- ============================================
-- HELPER FUNCTIONS (SECURITY DEFINER — bypass RLS)
-- ============================================

CREATE OR REPLACE FUNCTION public.is_project_member(_project_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = _project_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.has_project_in_org(_org_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.project_members pm
    JOIN public.projects p ON p.id = pm.project_id
    WHERE pm.user_id = auth.uid() AND p.organization_id = _org_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_project_member_via_task(_task_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.project_members pm ON pm.project_id = t.project_id
    WHERE t.id = _task_id AND pm.user_id = auth.uid()
  );
$$;


-- ============================================
-- UPDATED POLICIES
-- ============================================

-- 1. ORGANIZATIONS: allow reading orgs where user has project assignments
DROP POLICY "organizations_select" ON public.organizations;

CREATE POLICY "organizations_select"
  ON public.organizations FOR SELECT
  TO authenticated
  USING (
    public.is_member_of(id)
    OR EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
    OR public.has_project_in_org(id)
  );


-- 2. PROJECTS: direct bypass for project members
DROP POLICY "projects_select" ON public.projects;

CREATE POLICY "projects_select"
  ON public.projects FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'projects', 'read', organization_id,
      owner_id = auth.uid()
      OR public.is_project_member(id)
    )
    OR public.is_project_member(id)
  );


-- 3. PROJECT_MEMBERS: allow co-member visibility
DROP POLICY "project_members_select" ON public.project_members;

CREATE POLICY "project_members_select"
  ON public.project_members FOR SELECT
  TO authenticated
  USING (
    public.authorize('projects', 'read', public.project_org_id(project_id),
      user_id = auth.uid()
    )
    OR public.is_project_member(project_id)
  );


-- 4. TASKS: allow project members to read tasks in their projects
DROP POLICY "tasks_select" ON public.tasks;

CREATE POLICY "tasks_select"
  ON public.tasks FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.project_org_id(project_id),
      public.is_task_owner(id, created_by)
    )
    OR public.is_project_member(project_id)
  );


-- 5. TASKS INSERT: allow project members to create tasks
DROP POLICY "tasks_insert" ON public.tasks;

CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'create', public.project_org_id(project_id))
    OR public.is_project_member(project_id)
  );


-- 6. TASKS UPDATE: allow project members to update tasks
DROP POLICY "tasks_update" ON public.tasks;

CREATE POLICY "tasks_update"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'update',
      public.project_org_id(project_id),
      public.is_task_owner(id, created_by)
    )
    OR public.is_project_member(project_id)
  );


-- 7. TASK_ASSIGNMENTS: allow project members to view/manage assignments
DROP POLICY "task_assignments_select" ON public.task_assignments;

CREATE POLICY "task_assignments_select"
  ON public.task_assignments FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
    )
    OR public.is_project_member_via_task(task_id)
  );

DROP POLICY "task_assignments_insert" ON public.task_assignments;

CREATE POLICY "task_assignments_insert"
  ON public.task_assignments FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'assign', public.task_org_id(task_id))
    OR public.is_project_member_via_task(task_id)
  );

DROP POLICY "task_assignments_delete" ON public.task_assignments;

CREATE POLICY "task_assignments_delete"
  ON public.task_assignments FOR DELETE
  TO authenticated
  USING (
    public.authorize('tasks', 'assign', public.task_org_id(task_id))
    OR user_id = auth.uid()
    OR public.is_project_member_via_task(task_id)
  );
