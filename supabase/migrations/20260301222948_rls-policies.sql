-- ============================================
-- MIGRATION: RLS Policies
-- ============================================


-- ============================================
-- 1. CORE AUTHORIZE FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION public.authorize(
  _resource text,
  _action text,
  _org_id uuid,
  _is_owner boolean DEFAULT false
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  _scope public.permission_scope;
BEGIN
  SELECT rp.scope INTO _scope
  FROM public.organization_members om
  JOIN public.role_permissions rp ON rp.role_id = om.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE om.organization_id = _org_id
    AND om.user_id = auth.uid()
    AND p.resource = _resource
    AND p.action = _action;

  IF _scope IS NULL THEN RETURN false; END IF;
  IF _scope = 'all' THEN RETURN true; END IF;
  IF _scope = 'own' THEN RETURN _is_owner; END IF;

  RETURN false;
END;
$$;


-- Helper: check if user is a member of an org (no permission check, just membership)
CREATE OR REPLACE FUNCTION public.is_member_of(
  _org_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = _org_id
      AND user_id = auth.uid()
  );
$$;


-- Helper: resolve org_id from a project
CREATE OR REPLACE FUNCTION public.project_org_id(_project_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT organization_id FROM public.projects WHERE id = _project_id;
$$;


-- Helper: resolve org_id from a task (through project)
CREATE OR REPLACE FUNCTION public.task_org_id(_task_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT p.organization_id
  FROM public.tasks t
  JOIN public.projects p ON p.id = t.project_id
  WHERE t.id = _task_id;
$$;


-- Helper: resolve org_id from a ticket
CREATE OR REPLACE FUNCTION public.ticket_org_id(_ticket_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT organization_id FROM public.support_tickets WHERE id = _ticket_id;
$$;


-- Helper: check if current user owns or is assigned to a task
CREATE OR REPLACE FUNCTION public.is_task_owner(_task_id uuid, _created_by uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    _created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.task_assignments
      WHERE task_id = _task_id AND user_id = auth.uid()
    );
$$;


-- ============================================
-- 2. PERMISSIONS (reference table — read-only for authenticated)
-- ============================================

CREATE POLICY "permissions_select"
  ON public.permissions FOR SELECT
  TO authenticated
  USING (true);


-- ============================================
-- 3. ROLES (system roles + own org custom roles)
-- ============================================

CREATE POLICY "roles_select"
  ON public.roles FOR SELECT
  TO authenticated
  USING (
    is_system = true
    OR public.is_member_of(organization_id)
  );

CREATE POLICY "roles_insert"
  ON public.roles FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND public.authorize('members', 'manage_roles', organization_id)
  );

CREATE POLICY "roles_update"
  ON public.roles FOR UPDATE
  TO authenticated
  USING (
    is_system = false
    AND organization_id IS NOT NULL
    AND public.authorize('members', 'manage_roles', organization_id)
  );

CREATE POLICY "roles_delete"
  ON public.roles FOR DELETE
  TO authenticated
  USING (
    is_system = false
    AND organization_id IS NOT NULL
    AND public.authorize('members', 'manage_roles', organization_id)
  );


-- ============================================
-- 4. ROLE_PERMISSIONS
-- ============================================

CREATE POLICY "role_permissions_select"
  ON public.role_permissions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "role_permissions_insert"
  ON public.role_permissions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND r.is_system = false
        AND r.organization_id IS NOT NULL
        AND public.authorize('members', 'manage_roles', r.organization_id)
    )
  );

CREATE POLICY "role_permissions_update"
  ON public.role_permissions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND r.is_system = false
        AND r.organization_id IS NOT NULL
        AND public.authorize('members', 'manage_roles', r.organization_id)
    )
  );

CREATE POLICY "role_permissions_delete"
  ON public.role_permissions FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND r.is_system = false
        AND r.organization_id IS NOT NULL
        AND public.authorize('members', 'manage_roles', r.organization_id)
    )
  );


-- ============================================
-- 5. ORGANIZATIONS
-- ============================================

CREATE POLICY "organizations_select"
  ON public.organizations FOR SELECT
  TO authenticated
  USING (public.is_member_of(id));

CREATE POLICY "organizations_update"
  ON public.organizations FOR UPDATE
  TO authenticated
  USING (public.authorize('organizations', 'update', id));

CREATE POLICY "organizations_delete"
  ON public.organizations FOR DELETE
  TO authenticated
  USING (public.authorize('organizations', 'delete', id));


-- ============================================
-- 6. USERS
-- ============================================

-- Users can see other members in their org
CREATE POLICY "users_select"
  ON public.users FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR (
      organization_id IS NOT NULL
      AND public.is_member_of(organization_id)
    )
  );

-- Users can only update their own profile
CREATE POLICY "users_update"
  ON public.users FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());


-- ============================================
-- 7. ORGANIZATION_MEMBERS
-- ============================================

CREATE POLICY "org_members_select"
  ON public.organization_members FOR SELECT
  TO authenticated
  USING (public.is_member_of(organization_id));

CREATE POLICY "org_members_insert"
  ON public.organization_members FOR INSERT
  TO authenticated
  WITH CHECK (public.authorize('members', 'invite', organization_id));

CREATE POLICY "org_members_update"
  ON public.organization_members FOR UPDATE
  TO authenticated
  USING (
    public.authorize('members', 'manage_roles', organization_id)
    -- prevent users from changing their own role
    AND user_id != auth.uid()
  );

CREATE POLICY "org_members_delete"
  ON public.organization_members FOR DELETE
  TO authenticated
  USING (
    -- can remove others if has permission
    (public.authorize('members', 'remove', organization_id) AND user_id != auth.uid())
    -- can remove self (leave org)
    OR user_id = auth.uid()
  );


-- ============================================
-- 8. PROJECTS
-- ============================================

CREATE POLICY "projects_select"
  ON public.projects FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'projects', 'read', organization_id,
      -- "own" scope: user is owner or a project member
      owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = id AND pm.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "projects_insert"
  ON public.projects FOR INSERT
  TO authenticated
  WITH CHECK (public.authorize('projects', 'create', organization_id));

CREATE POLICY "projects_update"
  ON public.projects FOR UPDATE
  TO authenticated
  USING (
    public.authorize(
      'projects', 'update', organization_id,
      owner_id = auth.uid()
    )
  );

CREATE POLICY "projects_delete"
  ON public.projects FOR DELETE
  TO authenticated
  USING (public.authorize('projects', 'delete', organization_id));


-- ============================================
-- 9. PROJECT_MEMBERS
-- ============================================

CREATE POLICY "project_members_select"
  ON public.project_members FOR SELECT
  TO authenticated
  USING (
    public.authorize('projects', 'read', public.project_org_id(project_id),
      user_id = auth.uid()
    )
  );

CREATE POLICY "project_members_insert"
  ON public.project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('projects', 'manage', public.project_org_id(project_id))
    OR public.authorize('members', 'invite', public.project_org_id(project_id))
  );

CREATE POLICY "project_members_update"
  ON public.project_members FOR UPDATE
  TO authenticated
  USING (
    public.authorize('projects', 'manage', public.project_org_id(project_id))
  );

CREATE POLICY "project_members_delete"
  ON public.project_members FOR DELETE
  TO authenticated
  USING (
    public.authorize('projects', 'manage', public.project_org_id(project_id))
    OR public.authorize('members', 'remove', public.project_org_id(project_id))
    -- can leave a project yourself
    OR user_id = auth.uid()
  );


-- ============================================
-- 10. TASKS
-- ============================================

CREATE POLICY "tasks_select"
  ON public.tasks FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.project_org_id(project_id),
      public.is_task_owner(id, created_by)
    )
  );

CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'create', public.project_org_id(project_id))
  );

CREATE POLICY "tasks_update"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'update',
      public.project_org_id(project_id),
      public.is_task_owner(id, created_by)
    )
  );

CREATE POLICY "tasks_delete"
  ON public.tasks FOR DELETE
  TO authenticated
  USING (
    public.authorize('tasks', 'delete', public.project_org_id(project_id))
  );


-- ============================================
-- 11. TASK_ASSIGNMENTS
-- ============================================

CREATE POLICY "task_assignments_select"
  ON public.task_assignments FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
    )
  );

CREATE POLICY "task_assignments_insert"
  ON public.task_assignments FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'assign', public.task_org_id(task_id))
  );

CREATE POLICY "task_assignments_delete"
  ON public.task_assignments FOR DELETE
  TO authenticated
  USING (
    public.authorize('tasks', 'assign', public.task_org_id(task_id))
    -- can unassign yourself
    OR user_id = auth.uid()
  );


-- ============================================
-- 12. TASK_ACTIVITIES (read follows task, insert if can update task)
-- ============================================

CREATE POLICY "task_activities_select"
  ON public.task_activities FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
    )
  );

CREATE POLICY "task_activities_insert"
  ON public.task_activities FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'update', public.task_org_id(task_id))
  );


-- ============================================
-- 13. TASK_COMMENTS
-- ============================================

CREATE POLICY "task_comments_select"
  ON public.task_comments FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
    )
  );

-- can comment if can read the task
CREATE POLICY "task_comments_insert"
  ON public.task_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'read', public.task_org_id(task_id), true)
  );

-- can only edit own comments
CREATE POLICY "task_comments_update"
  ON public.task_comments FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- can delete own comments OR has tasks.delete
CREATE POLICY "task_comments_delete"
  ON public.task_comments FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.authorize('tasks', 'delete', public.task_org_id(task_id))
  );


-- ============================================
-- 14. SUPPORT_TICKETS
-- ============================================

CREATE POLICY "tickets_select"
  ON public.support_tickets FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'support_tickets', 'read', organization_id,
      customer_id = auth.uid() OR assigned_agent_id = auth.uid()
    )
  );

CREATE POLICY "tickets_insert"
  ON public.support_tickets FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('support_tickets', 'create', organization_id, customer_id = auth.uid())
    -- clients can only create tickets as themselves
    AND customer_id = auth.uid()
  );

CREATE POLICY "tickets_update"
  ON public.support_tickets FOR UPDATE
  TO authenticated
  USING (
    public.authorize(
      'support_tickets', 'update', organization_id,
      customer_id = auth.uid() OR assigned_agent_id = auth.uid()
    )
  );

CREATE POLICY "tickets_delete"
  ON public.support_tickets FOR DELETE
  TO authenticated
  USING (
    public.authorize('support_tickets', 'delete', organization_id)
  );


-- ============================================
-- 15. SUPPORT_TICKET_MESSAGES
-- ============================================

CREATE POLICY "ticket_messages_select"
  ON public.support_ticket_messages FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'support_tickets', 'read',
      public.ticket_org_id(ticket_id),
      sender_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.support_tickets t
        WHERE t.id = ticket_id
          AND (t.customer_id = auth.uid() OR t.assigned_agent_id = auth.uid())
      )
    )
    -- internal notes: only visible to non-clients (scope: all)
    AND (
      is_internal_note = false
      OR public.authorize('support_tickets', 'update', public.ticket_org_id(ticket_id))
    )
  );

CREATE POLICY "ticket_messages_insert"
  ON public.support_ticket_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    -- can message if can read the ticket
    public.authorize(
      'support_tickets', 'read',
      public.ticket_org_id(ticket_id),
      sender_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.support_tickets t
        WHERE t.id = ticket_id
          AND (t.customer_id = auth.uid() OR t.assigned_agent_id = auth.uid())
      )
    )
    -- only agents/admins can write internal notes
    AND (
      is_internal_note = false
      OR public.authorize('support_tickets', 'update', public.ticket_org_id(ticket_id))
    )
    -- must be the sender
    AND sender_id = auth.uid()
  );

CREATE POLICY "ticket_messages_delete"
  ON public.support_ticket_messages FOR DELETE
  TO authenticated
  USING (
    public.authorize('support_tickets', 'delete', public.ticket_org_id(ticket_id))
  );


-- ============================================
-- 16. PERFORMANCE INDEXES for RLS
-- ============================================

-- These support the joins in authorize() and helper functions
CREATE INDEX IF NOT EXISTS idx_org_members_user_org_role
  ON public.organization_members (user_id, organization_id, role_id);

CREATE INDEX IF NOT EXISTS idx_role_permissions_role_permission
  ON public.role_permissions (role_id, permission_id, scope);

CREATE INDEX IF NOT EXISTS idx_permissions_resource_action
  ON public.permissions (resource, action);

CREATE INDEX IF NOT EXISTS idx_task_assignments_task_user
  ON public.task_assignments (task_id, user_id);

CREATE INDEX IF NOT EXISTS idx_tickets_customer_agent
  ON public.support_tickets (customer_id, assigned_agent_id);