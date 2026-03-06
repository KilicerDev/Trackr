-- ============================================
-- SCHEMA: All enums, tables, indexes, triggers, RLS enablement
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

CREATE TYPE public.notification_type AS ENUM (
  'ticket_created',
  'ticket_assigned',
  'ticket_resolved',
  'ticket_message',
  'task_assigned',
  'task_status_change',
  'task_comment',
  'sla_breach'
);


-- ============================================
-- 2. SUPPORT TIERS (referenced by organizations)
-- ============================================

CREATE TABLE public.support_tiers (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  text NOT NULL UNIQUE,
  slug                  text NOT NULL UNIQUE,
  response_time_hours   int NOT NULL,
  resolution_time_hours int NOT NULL,
  description           text,
  sort_order            int NOT NULL DEFAULT 0,
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);


-- ============================================
-- 3. ORGANIZATIONS
-- ============================================

CREATE TABLE public.organizations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  slug            text NOT NULL UNIQUE,
  domain          text,
  logo_url        text,
  is_active       boolean NOT NULL DEFAULT true,
  website_url     text,
  notes           text,
  support_tier_id uuid REFERENCES public.support_tiers(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

CREATE INDEX idx_organizations_slug ON public.organizations (slug);
CREATE INDEX idx_organizations_deleted_at ON public.organizations (deleted_at) WHERE deleted_at IS NULL;


-- ============================================
-- 4. USERS
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
-- 5. PERMISSIONS
-- ============================================

CREATE TABLE public.permissions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource    text NOT NULL,
  action      text NOT NULL,
  description text,

  UNIQUE (resource, action)
);


-- ============================================
-- 6. ROLES
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

  UNIQUE (slug, organization_id)
);

CREATE INDEX idx_roles_organization_id ON public.roles (organization_id);


-- ============================================
-- 7. ROLE_PERMISSIONS
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
-- 8. ORGANIZATION_MEMBERS
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
-- 9. PROJECTS
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
-- 10. PROJECT_MEMBERS
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
-- 11. TASKS
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
-- 12. TASK_ASSIGNMENTS
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
-- 13. TASK_ACTIVITIES
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
-- 14. TASK_COMMENTS
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
-- 15. SUPPORT_TICKETS
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
-- 16. SUPPORT_TICKET_MESSAGES
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
-- 17. SYSTEM CONFIG
-- ============================================

CREATE TABLE public.system_config (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_name                text NOT NULL DEFAULT 'Trackr',
  app_logo_url            text,
  support_email           text,
  default_support_tier_id uuid REFERENCES public.support_tiers(id) ON DELETE SET NULL,
  default_timezone        text NOT NULL DEFAULT 'UTC',
  default_locale          text NOT NULL DEFAULT 'en',
  signups_enabled         boolean NOT NULL DEFAULT true,
  maintenance_mode        boolean NOT NULL DEFAULT false,
  max_orgs_per_user       int NOT NULL DEFAULT 1,
  max_projects_per_org    int NOT NULL DEFAULT 10,
  max_members_per_org     int NOT NULL DEFAULT 25,
  platform_organization_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  extra                   jsonb NOT NULL DEFAULT '{}',
  updated_at              timestamptz NOT NULL DEFAULT now(),
  updated_by              uuid REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX idx_system_config_singleton ON public.system_config ((true));


-- ============================================
-- 18. ORGANIZATION SETTINGS
-- ============================================

CREATE TABLE public.organization_settings (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id         uuid NOT NULL UNIQUE REFERENCES public.organizations(id) ON DELETE CASCADE,
  auto_assign_tickets     boolean NOT NULL DEFAULT false,
  default_ticket_priority public.ticket_priority NOT NULL DEFAULT 'medium',
  require_ticket_category boolean NOT NULL DEFAULT false,
  notify_on_ticket_created    boolean NOT NULL DEFAULT true,
  notify_on_ticket_assigned   boolean NOT NULL DEFAULT true,
  notify_on_ticket_resolved   boolean NOT NULL DEFAULT true,
  notify_on_task_assigned     boolean NOT NULL DEFAULT true,
  notify_on_task_status_change boolean NOT NULL DEFAULT true,
  notify_on_comment           boolean NOT NULL DEFAULT true,
  max_projects          int,
  max_members           int,
  custom_logo_url       text,
  primary_color         text,
  extra                 jsonb NOT NULL DEFAULT '{}',
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid REFERENCES public.users(id) ON DELETE SET NULL
);


-- ============================================
-- 19. SLA BREACHES
-- ============================================

CREATE TABLE public.sla_breaches (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id         uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  support_tier_id   uuid REFERENCES public.support_tiers(id) ON DELETE SET NULL,
  breach_type       text NOT NULL CHECK (breach_type IN ('response', 'resolution')),
  breached_at       timestamptz NOT NULL DEFAULT now(),
  expected_at       timestamptz NOT NULL,
  actual_at         timestamptz,
  escalated         boolean NOT NULL DEFAULT false,
  escalated_to      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  notes             text
);

CREATE INDEX idx_sla_breaches_ticket ON public.sla_breaches (ticket_id);


-- ============================================
-- 20. TICKET WORK LOGS
-- ============================================

CREATE TABLE public.ticket_work_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id   uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  minutes     int NOT NULL CHECK (minutes > 0),
  description text,
  logged_at   date NOT NULL DEFAULT CURRENT_DATE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ticket_work_logs_ticket_user ON public.ticket_work_logs (ticket_id, user_id);


-- ============================================
-- 21. TASK WORK LOGS
-- ============================================

CREATE TABLE public.task_work_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  minutes     int NOT NULL CHECK (minutes > 0),
  description text,
  logged_at   date NOT NULL DEFAULT CURRENT_DATE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_work_logs_task_user ON public.task_work_logs (task_id, user_id);


-- ============================================
-- 22. ORGANIZATION INVITATIONS
-- ============================================

CREATE TABLE public.organization_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  email text NOT NULL,
  role_id uuid NOT NULL REFERENCES public.roles(id),
  invited_by uuid NOT NULL REFERENCES public.users(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days',
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  UNIQUE (organization_id, email)
);

CREATE INDEX idx_invitations_org_id ON public.organization_invitations (organization_id);
CREATE INDEX idx_invitations_email ON public.organization_invitations (email);
CREATE INDEX idx_invitations_status ON public.organization_invitations (status) WHERE status = 'pending';


-- ============================================
-- 23. NOTIFICATIONS
-- ============================================

CREATE TABLE public.notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  recipient_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  actor_id        uuid REFERENCES public.users(id) ON DELETE SET NULL,
  type            public.notification_type NOT NULL,
  title           text NOT NULL,
  body            text,
  resource_type   text,
  resource_id     uuid,
  is_read         boolean NOT NULL DEFAULT false,
  read_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_recipient ON public.notifications (recipient_id, is_read, created_at DESC);
CREATE INDEX idx_notifications_org       ON public.notifications (organization_id, created_at DESC);


-- ============================================
-- 24. UPDATED_AT TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.organizations          FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users                  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.roles                  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.organization_members   FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.projects               FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.project_members        FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.tasks                  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.task_comments          FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.support_tickets        FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.support_tiers          FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.system_config          FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.organization_settings  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================
-- 25. ENABLE RLS ON ALL TABLES
-- ============================================

ALTER TABLE public.organizations              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_activities            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_comments              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_messages    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tiers              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_config              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_settings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sla_breaches               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_work_logs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_work_logs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invitations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications              ENABLE ROW LEVEL SECURITY;
