-- ============================================
-- MIGRATION: Initial Schema + RBAC System
-- ============================================

-- ============================================
-- 1. ENUMS
-- ============================================

CREATE TYPE public.project_status AS ENUM (
  'planning', 'active', 'paused', 'completed', 'archived'
);

CREATE TYPE public.task_status AS ENUM (
  'backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'
);

CREATE TYPE public.task_priority AS ENUM (
  'none', 'low', 'medium', 'high', 'urgent'
);

CREATE TYPE public.task_type AS ENUM (
  'task', 'bug', 'feature', 'improvement', 'epic'
);

CREATE TYPE public.environment_type AS ENUM (
  'production', 'staging', 'development'
);

CREATE TYPE public.activity_action AS ENUM (
  'updated_field', 'created', 'deleted'
);

CREATE TYPE public.activity_field AS ENUM (
  'status', 'priority', 'assignee_id', 'title', 'description', 'type', 'project_id', 'parent_id', 'milestone_id', 'environment', 'start_at', 'end_at'
);

CREATE TYPE public.ticket_status AS ENUM (
  'open', 'in_progress', 'waiting_on_customer', 'waiting_on_agent', 'resolved', 'closed'
);

CREATE TYPE public.ticket_priority AS ENUM (
  'low', 'medium', 'high', 'urgent'
);

CREATE TYPE public.ticket_channel AS ENUM (
  'email', 'api', 'chat', 'web_form'
);

CREATE TYPE public.ticket_category AS ENUM (
  'billing', 'technical_issue', 'feature_request', 'general'
);

CREATE TYPE public.permission_scope AS ENUM (
  'own', 'all'
);

CREATE TYPE public.task_assignment_role AS ENUM (
  'assignee', 'reviewer', 'watcher'
);


-- ============================================
-- 2. ORGANIZATIONS
-- ============================================

CREATE TABLE public.organizations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  slug          text NOT NULL UNIQUE,
  domain        text,
  logo_url      text,
  is_active     boolean NOT NULL DEFAULT true,
  website_url   text,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE INDEX idx_organizations_slug ON public.organizations (slug);
CREATE INDEX idx_organizations_deleted_at ON public.organizations (deleted_at) WHERE deleted_at IS NULL;


-- ============================================
-- 3. USERS (no global role column)
-- ============================================

CREATE TABLE public.users (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email           text NOT NULL UNIQUE,
  full_name       text NOT NULL,
  username        text NOT NULL,
  avatar_url      text,
  timezone        text NOT NULL DEFAULT 'UTC',
  locale          text NOT NULL DEFAULT 'en',
  organization_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  is_active       boolean NOT NULL DEFAULT true,
  last_seen_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

CREATE UNIQUE INDEX idx_users_username ON public.users (username) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_organization_id ON public.users (organization_id);
CREATE INDEX idx_users_email ON public.users (email);


-- ============================================
-- 4. PERMISSIONS
-- ============================================

CREATE TABLE public.permissions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource    text NOT NULL,
  action      text NOT NULL,
  description text,

  UNIQUE (resource, action)
);


-- ============================================
-- 5. ROLES
-- ============================================

CREATE TABLE public.roles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  slug            text NOT NULL,
  description     text,
  is_system       boolean NOT NULL DEFAULT false,
  organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  -- system roles have org = null, custom roles are scoped to an org
  UNIQUE (slug, organization_id)
);

CREATE INDEX idx_roles_organization_id ON public.roles (organization_id);


-- ============================================
-- 6. ROLE_PERMISSIONS
-- ============================================

CREATE TABLE public.role_permissions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id       uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  scope         public.permission_scope NOT NULL DEFAULT 'own',

  UNIQUE (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_role_id ON public.role_permissions (role_id);


-- ============================================
-- 7. ORGANIZATION_MEMBERS
-- ============================================

CREATE TABLE public.organization_members (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role_id         uuid NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  UNIQUE (organization_id, user_id)
);

CREATE INDEX idx_org_members_user_id ON public.organization_members (user_id);
CREATE INDEX idx_org_members_role_id ON public.organization_members (role_id);


-- ============================================
-- 8. PROJECTS
-- ============================================

CREATE TABLE public.projects (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  identifier      varchar(10) NOT NULL,
  description     text,
  status          public.project_status NOT NULL DEFAULT 'planning',
  owner_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  start_at        timestamptz,
  end_at          timestamptz,
  color           text,
  icon            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

CREATE INDEX idx_projects_organization_id ON public.projects (organization_id);
CREATE INDEX idx_projects_owner_id ON public.projects (owner_id);
CREATE INDEX idx_projects_status ON public.projects (status);
CREATE INDEX idx_projects_deleted_at ON public.projects (deleted_at) WHERE deleted_at IS NULL;


-- ============================================
-- 9. PROJECT_MEMBERS
-- ============================================

CREATE TABLE public.project_members (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role_id     uuid NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (project_id, user_id)
);

CREATE INDEX idx_project_members_user_id ON public.project_members (user_id);
CREATE INDEX idx_project_members_role_id ON public.project_members (role_id);


-- ============================================
-- 10. TASKS
-- ============================================

CREATE TABLE public.tasks (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title             text NOT NULL,
  description       text,
  status            public.task_status NOT NULL DEFAULT 'backlog',
  priority          public.task_priority NOT NULL DEFAULT 'none',
  type              public.task_type NOT NULL DEFAULT 'task',
  project_id        uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  created_by        uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  updated_by        uuid REFERENCES public.users(id) ON DELETE SET NULL,
  parent_id         uuid REFERENCES public.tasks(id) ON DELETE SET NULL,
  milestone_id      uuid,
  short_id          text,
  start_at          timestamptz,
  end_at            timestamptz,
  environment       public.environment_type,
  affected_version  text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);

CREATE INDEX idx_tasks_project_id ON public.tasks (project_id);
CREATE INDEX idx_tasks_created_by ON public.tasks (created_by);
CREATE INDEX idx_tasks_status ON public.tasks (status);
CREATE INDEX idx_tasks_priority ON public.tasks (priority);
CREATE INDEX idx_tasks_parent_id ON public.tasks (parent_id);
CREATE INDEX idx_tasks_deleted_at ON public.tasks (deleted_at) WHERE deleted_at IS NULL;


-- ============================================
-- 11. TASK_ASSIGNMENTS
-- ============================================

CREATE TABLE public.task_assignments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role        public.task_assignment_role NOT NULL DEFAULT 'assignee',
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid REFERENCES public.users(id) ON DELETE SET NULL,

  UNIQUE (task_id, user_id, role)
);

CREATE INDEX idx_task_assignments_user_id ON public.task_assignments (user_id);
CREATE INDEX idx_task_assignments_task_id ON public.task_assignments (task_id);


-- ============================================
-- 12. TASK_ACTIVITIES
-- ============================================

CREATE TABLE public.task_activities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  action      public.activity_action NOT NULL,
  field_name  public.activity_field,
  old_value   text,
  new_value   text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_activities_task_id ON public.task_activities (task_id);
CREATE INDEX idx_task_activities_user_id ON public.task_activities (user_id);
CREATE INDEX idx_task_activities_created_at ON public.task_activities (created_at);


-- ============================================
-- 13. TASK_COMMENTS
-- ============================================

CREATE TABLE public.task_comments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  content     text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE INDEX idx_task_comments_task_id ON public.task_comments (task_id);
CREATE INDEX idx_task_comments_user_id ON public.task_comments (user_id);


-- ============================================
-- 14. SUPPORT_TICKETS
-- ============================================

CREATE TABLE public.support_tickets (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  subject             text NOT NULL,
  description         text,
  status              public.ticket_status NOT NULL DEFAULT 'open',
  priority            public.ticket_priority NOT NULL DEFAULT 'medium',
  channel             public.ticket_channel NOT NULL DEFAULT 'web_form',
  assigned_agent_id   uuid REFERENCES public.users(id) ON DELETE SET NULL,
  category            public.ticket_category,
  first_response_at   timestamptz,
  sla_deadline        timestamptz,
  resolved_at         timestamptz,
  satisfaction_score  smallint CHECK (satisfaction_score >= 1 AND satisfaction_score <= 5),
  metadata            jsonb DEFAULT '{}',
  device_id           text,
  related_task_id     uuid REFERENCES public.tasks(id) ON DELETE SET NULL,
  organization_id     uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);

CREATE INDEX idx_tickets_customer_id ON public.support_tickets (customer_id);
CREATE INDEX idx_tickets_assigned_agent_id ON public.support_tickets (assigned_agent_id);
CREATE INDEX idx_tickets_status ON public.support_tickets (status);
CREATE INDEX idx_tickets_organization_id ON public.support_tickets (organization_id);
CREATE INDEX idx_tickets_deleted_at ON public.support_tickets (deleted_at) WHERE deleted_at IS NULL;


-- ============================================
-- 15. SUPPORT_TICKET_MESSAGES
-- ============================================

CREATE TABLE public.support_ticket_messages (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id         uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  is_internal_note  boolean NOT NULL DEFAULT false,
  body              text NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);

CREATE INDEX idx_ticket_messages_ticket_id ON public.support_ticket_messages (ticket_id);
CREATE INDEX idx_ticket_messages_sender_id ON public.support_ticket_messages (sender_id);


-- ============================================
-- 16. UPDATED_AT TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.organizations     FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users             FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.roles             FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.organization_members FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.projects          FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.project_members   FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.tasks             FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.task_comments     FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.support_tickets   FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================
-- 17. ENABLE RLS ON ALL TABLES
-- ============================================

ALTER TABLE public.organizations          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_activities        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_comments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;


-- ============================================
-- 18. SEED PERMISSIONS
-- ============================================

INSERT INTO public.permissions (id, resource, action, description) VALUES
  -- Tasks
  (gen_random_uuid(), 'tasks',              'create',       'Create new tasks'),
  (gen_random_uuid(), 'tasks',              'read',         'View tasks'),
  (gen_random_uuid(), 'tasks',              'update',       'Update tasks'),
  (gen_random_uuid(), 'tasks',              'delete',       'Delete tasks'),
  (gen_random_uuid(), 'tasks',              'assign',       'Assign tasks to users'),
  -- Support Tickets
  (gen_random_uuid(), 'support_tickets',    'create',       'Create support tickets'),
  (gen_random_uuid(), 'support_tickets',    'read',         'View support tickets'),
  (gen_random_uuid(), 'support_tickets',    'update',       'Update support tickets'),
  (gen_random_uuid(), 'support_tickets',    'delete',       'Delete support tickets'),
  (gen_random_uuid(), 'support_tickets',    'assign',       'Assign tickets to agents'),
  -- Projects
  (gen_random_uuid(), 'projects',           'create',       'Create projects'),
  (gen_random_uuid(), 'projects',           'read',         'View projects'),
  (gen_random_uuid(), 'projects',           'update',       'Update projects'),
  (gen_random_uuid(), 'projects',           'delete',       'Delete projects'),
  (gen_random_uuid(), 'projects',           'manage',       'Manage project settings and members'),
  -- Members
  (gen_random_uuid(), 'members',            'invite',       'Invite users to org or project'),
  (gen_random_uuid(), 'members',            'remove',       'Remove users from org or project'),
  (gen_random_uuid(), 'members',            'manage_roles', 'Change user roles'),
  -- Organization
  (gen_random_uuid(), 'organizations',      'update',       'Update organization settings'),
  (gen_random_uuid(), 'organizations',      'billing',      'Manage billing'),
  (gen_random_uuid(), 'organizations',      'delete',       'Delete organization');


-- ============================================
-- 19. SEED SYSTEM ROLES
-- ============================================

INSERT INTO public.roles (id, name, slug, description, is_system, organization_id) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Owner',     'owner',     'Full access to everything. Cannot be restricted.',               true, null),
  ('a0000000-0000-0000-0000-000000000002', 'Developer', 'developer', 'Full access to projects and tasks. Limited org management.',      true, null),
  ('a0000000-0000-0000-0000-000000000003', 'Manager',   'manager',   'Manage tasks, tickets, and members. Configurable per org.',       true, null),
  ('a0000000-0000-0000-0000-000000000004', 'Watcher',   'watcher',   'Read-only access to tasks and tickets.',                          true, null),
  ('a0000000-0000-0000-0000-000000000005', 'Client',    'client',    'Can create and view own support tickets.',                        true, null);


-- ============================================
-- 20. SEED ROLE PERMISSIONS
-- ============================================

-- Helper: assign all actions for a resource to a role with a given scope
-- We reference permissions by (resource, action) and roles by known IDs

-- ─────────────────────────────────
-- OWNER: everything → scope: all
-- ─────────────────────────────────
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001', p.id, 'all'
FROM public.permissions p;

-- ─────────────────────────────────
-- DEVELOPER: all task/project access, limited org
-- ─────────────────────────────────
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000002', p.id, 'all'
FROM public.permissions p
WHERE (p.resource = 'tasks')
   OR (p.resource = 'projects')
   OR (p.resource = 'support_tickets' AND p.action IN ('create', 'read', 'update'))
   OR (p.resource = 'members' AND p.action = 'invite');

-- ─────────────────────────────────
-- MANAGER: tasks, tickets, members, project read/update
-- ─────────────────────────────────
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000003', p.id, 'all'
FROM public.permissions p
WHERE (p.resource = 'tasks')
   OR (p.resource = 'support_tickets')
   OR (p.resource = 'projects' AND p.action IN ('read', 'update'))
   OR (p.resource = 'members' AND p.action IN ('invite', 'remove'));

-- ─────────────────────────────────
-- WATCHER: read-only → scope: all
-- ─────────────────────────────────
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000004', p.id, 'all'
FROM public.permissions p
WHERE p.action = 'read'
  AND p.resource IN ('tasks', 'support_tickets', 'projects');

-- ─────────────────────────────────
-- CLIENT: own tickets only → scope: own
-- ─────────────────────────────────
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000005', p.id, 'own'
FROM public.permissions p
WHERE (p.resource = 'support_tickets' AND p.action IN ('create', 'read', 'update'));

-- Client can also read own tasks (if linked to tickets)
INSERT INTO public.role_permissions (id, role_id, permission_id, scope)
SELECT gen_random_uuid(), 'a0000000-0000-0000-0000-000000000005', p.id, 'own'
FROM public.permissions p
WHERE p.resource = 'tasks' AND p.action = 'read';


-- ============================================
-- 21. HELPER FUNCTION: Check permission
-- ============================================

CREATE OR REPLACE FUNCTION public.user_has_permission(
  _user_id         uuid,
  _organization_id uuid,
  _resource        text,
  _action          text,
  _resource_owner_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  _role_id uuid;
  _scope   public.permission_scope;
BEGIN
  -- Get the user's role in the organization
  SELECT om.role_id INTO _role_id
  FROM public.organization_members om
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;

  IF _role_id IS NULL THEN
    RETURN false;
  END IF;

  -- Check if the role has the requested permission
  SELECT rp.scope INTO _scope
  FROM public.role_permissions rp
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE rp.role_id = _role_id
    AND p.resource = _resource
    AND p.action = _action;

  IF _scope IS NULL THEN
    RETURN false;
  END IF;

  -- scope: all = can access everything
  IF _scope = 'all' THEN
    RETURN true;
  END IF;

  -- scope: own = can only access own resources
  IF _scope = 'own' THEN
    IF _resource_owner_id IS NULL THEN
      -- No owner context provided, default to only showing own
      RETURN true;
    END IF;
    RETURN _user_id = _resource_owner_id;
  END IF;

  RETURN false;
END;
$$;


-- ============================================
-- 22. HELPER FUNCTION: Get user role in org
-- ============================================

CREATE OR REPLACE FUNCTION public.get_user_role(
  _user_id         uuid,
  _organization_id uuid
)
RETURNS TABLE (
  role_id   uuid,
  role_slug text,
  role_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT r.id, r.slug, r.name
  FROM public.organization_members om
  JOIN public.roles r ON r.id = om.role_id
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;
END;
$$;


-- ============================================
-- 23. HELPER FUNCTION: Get all permissions for a user in an org
-- ============================================

CREATE OR REPLACE FUNCTION public.get_user_permissions(
  _user_id         uuid,
  _organization_id uuid
)
RETURNS TABLE (
  resource   text,
  action     text,
  scope      public.permission_scope
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT p.resource, p.action, rp.scope
  FROM public.organization_members om
  JOIN public.role_permissions rp ON rp.role_id = om.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;
END;
$$;