-- ============================================
-- MIGRATION: Support Tiers + System Config + Organization Settings
-- ============================================


-- ============================================
-- 1. SUPPORT TIERS (dynamic, configurable by platform owner)
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

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.support_tiers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================
-- 2. ADD TIER FK TO ORGANIZATIONS
-- ============================================

ALTER TABLE public.organizations
  ADD COLUMN support_tier_id uuid REFERENCES public.support_tiers(id) ON DELETE SET NULL;


-- ============================================
-- 3. SYSTEM CONFIG (single-row global settings, only app owner edits)
-- ============================================

CREATE TABLE public.system_config (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Branding
  app_name              text NOT NULL DEFAULT 'Trackr',
  app_logo_url          text,
  support_email         text,

  -- Defaults for new orgs
  default_support_tier_id uuid REFERENCES public.support_tiers(id) ON DELETE SET NULL,
  default_timezone      text NOT NULL DEFAULT 'UTC',
  default_locale        text NOT NULL DEFAULT 'en',

  -- Feature flags
  signups_enabled       boolean NOT NULL DEFAULT true,
  maintenance_mode      boolean NOT NULL DEFAULT false,
  max_orgs_per_user     int NOT NULL DEFAULT 1,
  max_projects_per_org  int NOT NULL DEFAULT 10,
  max_members_per_org   int NOT NULL DEFAULT 25,

  -- Misc
  extra                 jsonb NOT NULL DEFAULT '{}',
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX idx_system_config_singleton ON public.system_config ((true));

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.system_config
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================
-- 4. ORGANIZATION SETTINGS (per-org overrides)
-- ============================================

CREATE TABLE public.organization_settings (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL UNIQUE REFERENCES public.organizations(id) ON DELETE CASCADE,

  -- Ticket settings
  auto_assign_tickets   boolean NOT NULL DEFAULT false,
  default_ticket_priority public.ticket_priority NOT NULL DEFAULT 'medium',
  require_ticket_category boolean NOT NULL DEFAULT false,

  -- Notification preferences
  notify_on_ticket_created    boolean NOT NULL DEFAULT true,
  notify_on_ticket_assigned   boolean NOT NULL DEFAULT true,
  notify_on_ticket_resolved   boolean NOT NULL DEFAULT true,
  notify_on_task_assigned     boolean NOT NULL DEFAULT true,
  notify_on_task_status_change boolean NOT NULL DEFAULT true,
  notify_on_comment           boolean NOT NULL DEFAULT true,

  -- Limits (null = use system default)
  max_projects          int,
  max_members           int,

  -- Custom branding
  custom_logo_url       text,
  primary_color         text,

  -- Misc
  extra                 jsonb NOT NULL DEFAULT '{}',
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.organization_settings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================
-- 5. SLA BREACHES LOG (tracking)
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
-- 6. HELPER: Get effective SLA for a ticket
-- ============================================

CREATE OR REPLACE FUNCTION public.get_effective_sla(
  _organization_id uuid
)
RETURNS TABLE (
  response_time_hours   int,
  resolution_time_hours int,
  support_tier_id       uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    st.response_time_hours,
    st.resolution_time_hours,
    st.id
  FROM public.organizations o
  JOIN public.support_tiers st ON st.id = o.support_tier_id
  WHERE o.id = _organization_id
    AND st.is_active = true;

  IF NOT FOUND THEN
    -- Fallback: use the system default tier
    RETURN QUERY
    SELECT
      st.response_time_hours,
      st.resolution_time_hours,
      st.id
    FROM public.system_config sc
    JOIN public.support_tiers st ON st.id = sc.default_support_tier_id
    WHERE st.is_active = true
    LIMIT 1;
  END IF;
END;
$$;


-- ============================================
-- 7. AUTO-SET SLA DEADLINE ON TICKET CREATE
-- ============================================

CREATE OR REPLACE FUNCTION public.set_ticket_sla_deadline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _sla record;
BEGIN
  SELECT * INTO _sla
  FROM public.get_effective_sla(NEW.organization_id);

  IF _sla IS NOT NULL AND _sla.resolution_time_hours IS NOT NULL THEN
    NEW.sla_deadline := NEW.created_at + (_sla.resolution_time_hours || ' hours')::interval;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_set_ticket_sla
  BEFORE INSERT ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_ticket_sla_deadline();


-- ============================================
-- 8. RLS POLICIES
-- ============================================

ALTER TABLE public.support_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sla_breaches ENABLE ROW LEVEL SECURITY;

-- Support tiers: everyone can read, only owner can manage
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

-- System config: everyone can read, only owner can update
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

-- Org settings: members can read, org admins can update
CREATE POLICY "org_settings_select" ON public.organization_settings
  FOR SELECT TO authenticated
  USING (public.is_member_of(organization_id));

CREATE POLICY "org_settings_insert" ON public.organization_settings
  FOR INSERT TO authenticated
  WITH CHECK (public.authorize('organizations', 'update', organization_id));

CREATE POLICY "org_settings_update" ON public.organization_settings
  FOR UPDATE TO authenticated
  USING (public.authorize('organizations', 'update', organization_id));

-- SLA breaches: visible to members of the ticket's org
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
-- 9. SEED DEFAULT TIERS
-- ============================================

INSERT INTO public.support_tiers (id, name, slug, response_time_hours, resolution_time_hours, description, sort_order) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Basic',    'basic',    48, 168, 'Standard support with relaxed SLA',     0),
  ('10000000-0000-0000-0000-000000000002', 'Standard', 'standard', 24,  72, 'Improved response and resolution times', 1),
  ('10000000-0000-0000-0000-000000000003', 'Premium',  'premium',   8,  24, 'Priority support for important clients', 2),
  ('10000000-0000-0000-0000-000000000004', 'Gold',     'gold',      2,   8, 'Top-tier SLA with fastest turnaround',  3);


-- ============================================
-- 10. SEED SYSTEM CONFIG
-- ============================================

INSERT INTO public.system_config (
  app_name,
  support_email,
  default_support_tier_id
) VALUES (
  'Trackr',
  'support@kilicsoftware.com',
  '10000000-0000-0000-0000-000000000001'
);
