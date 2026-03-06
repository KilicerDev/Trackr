-- ============================================
-- RLS POLICIES: All policies (final correct versions)
-- ============================================


-- ============================================
-- 1. PERMISSIONS (reference table — read-only)
-- ============================================

CREATE POLICY "permissions_select"
  ON public.permissions FOR SELECT
  TO authenticated
  USING (true);


-- ============================================
-- 2. ROLES
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
-- 3. ROLE_PERMISSIONS
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
-- 4. ORGANIZATIONS
-- (includes owner visibility + cross-org project access + insert policy)
-- ============================================

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

CREATE POLICY "organizations_insert"
  ON public.organizations FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );

CREATE POLICY "organizations_update"
  ON public.organizations FOR UPDATE
  TO authenticated
  USING (public.authorize('organizations', 'update', id));

CREATE POLICY "organizations_delete"
  ON public.organizations FOR DELETE
  TO authenticated
  USING (public.authorize('organizations', 'delete', id));


-- ============================================
-- 5. USERS
-- (includes platform member visibility in both directions)
-- ============================================

CREATE POLICY "users_select"
  ON public.users FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR (
      organization_id IS NOT NULL
      AND public.is_member_of(organization_id)
    )
    -- Platform org members can see all users
    OR public.is_platform_member(auth.uid())
    -- All authenticated users can see platform org members (support team)
    OR public.is_platform_member(id)
  );

CREATE POLICY "users_update"
  ON public.users FOR UPDATE
  TO authenticated
  USING (
    id = auth.uid()
    OR public.authorize('members', 'manage_roles', organization_id)
  )
  WITH CHECK (
    id = auth.uid()
    OR public.authorize('members', 'manage_roles', organization_id)
  );


-- ============================================
-- 6. ORGANIZATION_MEMBERS
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
    AND user_id != auth.uid()
  );

CREATE POLICY "org_members_delete"
  ON public.organization_members FOR DELETE
  TO authenticated
  USING (
    (public.authorize('members', 'remove', organization_id) AND user_id != auth.uid())
    OR user_id = auth.uid()
  );


-- ============================================
-- 7. PROJECTS
-- (includes cross-org project member access)
-- ============================================

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
-- 8. PROJECT_MEMBERS
-- (includes cross-org co-member visibility)
-- ============================================

CREATE POLICY "project_members_select"
  ON public.project_members FOR SELECT
  TO authenticated
  USING (
    public.authorize('projects', 'read', public.project_org_id(project_id),
      user_id = auth.uid()
    )
    OR public.is_project_member(project_id)
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
    OR user_id = auth.uid()
  );


-- ============================================
-- 9. TASKS
-- (includes cross-org project member access)
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
    OR public.is_project_member(project_id)
  );

CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'create', public.project_org_id(project_id))
    OR public.is_project_member(project_id)
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
    OR public.is_project_member(project_id)
  );

CREATE POLICY "tasks_delete"
  ON public.tasks FOR DELETE
  TO authenticated
  USING (
    public.authorize('tasks', 'delete', public.project_org_id(project_id))
  );


-- ============================================
-- 10. TASK_ASSIGNMENTS
-- (includes cross-org project member access)
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
    OR public.is_project_member_via_task(task_id)
  );

CREATE POLICY "task_assignments_insert"
  ON public.task_assignments FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'assign', public.task_org_id(task_id))
    OR public.is_project_member_via_task(task_id)
  );

CREATE POLICY "task_assignments_delete"
  ON public.task_assignments FOR DELETE
  TO authenticated
  USING (
    public.authorize('tasks', 'assign', public.task_org_id(task_id))
    OR user_id = auth.uid()
    OR public.is_project_member_via_task(task_id)
  );


-- ============================================
-- 11. TASK_ACTIVITIES
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
-- 12. TASK_COMMENTS
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

CREATE POLICY "task_comments_insert"
  ON public.task_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize('tasks', 'read', public.task_org_id(task_id), true)
  );

CREATE POLICY "task_comments_update"
  ON public.task_comments FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "task_comments_delete"
  ON public.task_comments FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.authorize('tasks', 'delete', public.task_org_id(task_id))
  );


-- ============================================
-- 13. SUPPORT_TICKETS
-- (tickets_insert: allows admins on behalf + requires support_tier_id)
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
    AND EXISTS (
      SELECT 1 FROM public.organizations o
      WHERE o.id = organization_id
        AND o.support_tier_id IS NOT NULL
    )
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
-- 14. SUPPORT_TICKET_MESSAGES
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
    AND (
      is_internal_note = false
      OR public.authorize('support_tickets', 'update', public.ticket_org_id(ticket_id))
    )
  );

CREATE POLICY "ticket_messages_insert"
  ON public.support_ticket_messages FOR INSERT
  TO authenticated
  WITH CHECK (
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
    AND (
      is_internal_note = false
      OR public.authorize('support_tickets', 'update', public.ticket_org_id(ticket_id))
    )
    AND sender_id = auth.uid()
  );

CREATE POLICY "ticket_messages_delete"
  ON public.support_ticket_messages FOR DELETE
  TO authenticated
  USING (
    public.authorize('support_tickets', 'delete', public.ticket_org_id(ticket_id))
  );


-- ============================================
-- 15. SUPPORT TIERS
-- ============================================

CREATE POLICY "support_tiers_select" ON public.support_tiers
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "support_tiers_insert" ON public.support_tiers
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );

CREATE POLICY "support_tiers_update" ON public.support_tiers
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );

CREATE POLICY "support_tiers_delete" ON public.support_tiers
  FOR DELETE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );


-- ============================================
-- 16. SYSTEM CONFIG
-- ============================================

CREATE POLICY "system_config_select" ON public.system_config
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "system_config_update" ON public.system_config
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );


-- ============================================
-- 17. ORGANIZATION SETTINGS
-- ============================================

CREATE POLICY "org_settings_select" ON public.organization_settings
  FOR SELECT TO authenticated
  USING (public.is_member_of(organization_id));

CREATE POLICY "org_settings_insert" ON public.organization_settings
  FOR INSERT TO authenticated
  WITH CHECK (public.authorize('organizations', 'update', organization_id));

CREATE POLICY "org_settings_update" ON public.organization_settings
  FOR UPDATE TO authenticated
  USING (public.authorize('organizations', 'update', organization_id));


-- ============================================
-- 18. SLA BREACHES
-- ============================================

CREATE POLICY "sla_breaches_select" ON public.sla_breaches
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id
        AND public.authorize('support_tickets', 'read', t.organization_id, t.customer_id = auth.uid())
    )
  );


-- ============================================
-- 19. TICKET WORK LOGS
-- (insert requires support_tickets.update, not just read)
-- ============================================

CREATE POLICY "ticket_work_logs_select"
  ON public.ticket_work_logs FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'support_tickets', 'read',
      public.ticket_org_id(ticket_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.support_tickets t
        WHERE t.id = ticket_id
          AND (t.customer_id = auth.uid() OR t.assigned_agent_id = auth.uid())
      )
    )
  );

CREATE POLICY "ticket_work_logs_insert"
  ON public.ticket_work_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize(
      'support_tickets', 'update',
      public.ticket_org_id(ticket_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.support_tickets t
        WHERE t.id = ticket_id
          AND (t.customer_id = auth.uid() OR t.assigned_agent_id = auth.uid())
      )
    )
    AND user_id = auth.uid()
  );

CREATE POLICY "ticket_work_logs_delete"
  ON public.ticket_work_logs FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.authorize('support_tickets', 'delete', public.ticket_org_id(ticket_id))
  );


-- ============================================
-- 20. TASK WORK LOGS
-- ============================================

CREATE POLICY "task_work_logs_select"
  ON public.task_work_logs FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.task_assignments ta
        WHERE ta.task_id = task_work_logs.task_id
          AND ta.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "task_work_logs_insert"
  ON public.task_work_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.task_assignments ta
        WHERE ta.task_id = task_work_logs.task_id
          AND ta.user_id = auth.uid()
      )
    )
    AND user_id = auth.uid()
  );

CREATE POLICY "task_work_logs_delete"
  ON public.task_work_logs FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.authorize('tasks', 'delete', public.task_org_id(task_id))
  );


-- ============================================
-- 21. ORGANIZATION INVITATIONS
-- ============================================

CREATE POLICY "invitations_select"
  ON public.organization_invitations FOR SELECT
  TO authenticated
  USING (public.is_member_of(organization_id));

CREATE POLICY "invitations_insert"
  ON public.organization_invitations FOR INSERT
  TO authenticated
  WITH CHECK (public.authorize('members', 'invite', organization_id));

CREATE POLICY "invitations_update"
  ON public.organization_invitations FOR UPDATE
  TO authenticated
  USING (public.authorize('members', 'invite', organization_id));

CREATE POLICY "invitations_delete"
  ON public.organization_invitations FOR DELETE
  TO authenticated
  USING (public.authorize('members', 'invite', organization_id));


-- ============================================
-- 22. NOTIFICATIONS
-- ============================================

CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT TO authenticated
  USING (recipient_id = auth.uid());

CREATE POLICY "notifications_update" ON public.notifications
  FOR UPDATE TO authenticated
  USING (recipient_id = auth.uid());

CREATE POLICY "notifications_delete" ON public.notifications
  FOR DELETE TO authenticated
  USING (recipient_id = auth.uid());

CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (false);


-- ============================================
-- 23. PERFORMANCE INDEXES for RLS
-- ============================================

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
