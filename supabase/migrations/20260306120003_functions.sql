-- ============================================
-- FUNCTIONS: All helper functions (final versions)
--
-- Every SECURITY DEFINER function includes SET search_path = ''
-- authorize() and is_member_of() use platform-org-first fallback
-- ============================================


-- ============================================
-- 1. authorize() — used by RLS policies
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
SET search_path = ''
AS $$
DECLARE
  _scope public.permission_scope;
  _platform_org_id uuid;
BEGIN
  SELECT sc.platform_organization_id INTO _platform_org_id
  FROM public.system_config sc LIMIT 1;

  -- Try platform org membership first (global access)
  IF _platform_org_id IS NOT NULL THEN
    SELECT rp.scope INTO _scope
    FROM public.organization_members om
    JOIN public.role_permissions rp ON rp.role_id = om.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE om.organization_id = _platform_org_id
      AND om.user_id = auth.uid()
      AND p.resource = _resource
      AND p.action = _action;

    IF _scope IS NOT NULL THEN
      IF _scope = 'all' THEN RETURN true; END IF;
      IF _scope = 'own' THEN RETURN _is_owner; END IF;
    END IF;
  END IF;

  -- Fall back to specific org membership
  _scope := NULL;
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


-- ============================================
-- 2. is_member_of() — platform team members have implicit membership
-- ============================================

CREATE OR REPLACE FUNCTION public.is_member_of(
  _org_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
  _platform_org_id uuid;
BEGIN
  SELECT sc.platform_organization_id INTO _platform_org_id
  FROM public.system_config sc LIMIT 1;

  IF _platform_org_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.organization_members
      WHERE organization_id = _platform_org_id
        AND user_id = auth.uid()
    ) THEN
      RETURN true;
    END IF;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = _org_id
      AND user_id = auth.uid()
  );
END;
$$;


-- ============================================
-- 3. project_org_id()
-- ============================================

CREATE OR REPLACE FUNCTION public.project_org_id(_project_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT organization_id FROM public.projects WHERE id = _project_id;
$$;


-- ============================================
-- 4. task_org_id()
-- ============================================

CREATE OR REPLACE FUNCTION public.task_org_id(_task_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT p.organization_id
  FROM public.tasks t
  JOIN public.projects p ON p.id = t.project_id
  WHERE t.id = _task_id;
$$;


-- ============================================
-- 5. ticket_org_id()
-- ============================================

CREATE OR REPLACE FUNCTION public.ticket_org_id(_ticket_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT organization_id FROM public.support_tickets WHERE id = _ticket_id;
$$;


-- ============================================
-- 6. is_task_owner()
-- ============================================

CREATE OR REPLACE FUNCTION public.is_task_owner(_task_id uuid, _created_by uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT
    _created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.task_assignments
      WHERE task_id = _task_id AND user_id = auth.uid()
    );
$$;


-- ============================================
-- 7. is_platform_member()
-- ============================================

CREATE OR REPLACE FUNCTION public.is_platform_member(_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.system_config sc
    JOIN public.organization_members om
      ON om.organization_id = sc.platform_organization_id
    WHERE om.user_id = _user_id
  );
$$;


-- ============================================
-- 8. is_project_member()
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


-- ============================================
-- 9. has_project_in_org()
-- ============================================

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


-- ============================================
-- 10. is_project_member_via_task()
-- ============================================

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
-- 11. user_has_permission()
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
SET search_path = ''
AS $$
DECLARE
  _role_id uuid;
  _scope   public.permission_scope;
  _platform_org_id uuid;
BEGIN
  SELECT sc.platform_organization_id INTO _platform_org_id
  FROM public.system_config sc LIMIT 1;

  -- Try platform org membership first
  IF _platform_org_id IS NOT NULL THEN
    SELECT om.role_id INTO _role_id
    FROM public.organization_members om
    WHERE om.organization_id = _platform_org_id
      AND om.user_id = _user_id;
  END IF;

  -- Fall back to specific org membership
  IF _role_id IS NULL THEN
    SELECT om.role_id INTO _role_id
    FROM public.organization_members om
    WHERE om.organization_id = _organization_id
      AND om.user_id = _user_id;
  END IF;

  IF _role_id IS NULL THEN RETURN false; END IF;

  SELECT rp.scope INTO _scope
  FROM public.role_permissions rp
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE rp.role_id = _role_id
    AND p.resource = _resource
    AND p.action = _action;

  IF _scope IS NULL THEN RETURN false; END IF;
  IF _scope = 'all' THEN RETURN true; END IF;
  IF _scope = 'own' THEN
    IF _resource_owner_id IS NULL THEN RETURN true; END IF;
    RETURN _user_id = _resource_owner_id;
  END IF;

  RETURN false;
END;
$$;


-- ============================================
-- 12. get_user_role()
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
SET search_path = ''
AS $$
DECLARE
  _platform_org_id uuid;
BEGIN
  SELECT sc.platform_organization_id INTO _platform_org_id
  FROM public.system_config sc LIMIT 1;

  -- Try platform org membership first
  IF _platform_org_id IS NOT NULL THEN
    RETURN QUERY
    SELECT r.id, r.slug, r.name
    FROM public.organization_members om
    JOIN public.roles r ON r.id = om.role_id
    WHERE om.organization_id = _platform_org_id
      AND om.user_id = _user_id;

    IF FOUND THEN RETURN; END IF;
  END IF;

  -- Fall back to specific org membership
  RETURN QUERY
  SELECT r.id, r.slug, r.name
  FROM public.organization_members om
  JOIN public.roles r ON r.id = om.role_id
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;
END;
$$;


-- ============================================
-- 13. get_user_permissions()
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
SET search_path = ''
AS $$
DECLARE
  _platform_org_id uuid;
BEGIN
  SELECT sc.platform_organization_id INTO _platform_org_id
  FROM public.system_config sc LIMIT 1;

  -- Try platform org membership first
  IF _platform_org_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = _platform_org_id
      AND user_id = _user_id
  ) THEN
    RETURN QUERY
    SELECT p.resource, p.action, rp.scope
    FROM public.organization_members om
    JOIN public.role_permissions rp ON rp.role_id = om.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE om.organization_id = _platform_org_id
      AND om.user_id = _user_id;
    RETURN;
  END IF;

  -- Fall back to specific org membership
  RETURN QUERY
  SELECT p.resource, p.action, rp.scope
  FROM public.organization_members om
  JOIN public.role_permissions rp ON rp.role_id = om.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;
END;
$$;


-- ============================================
-- 14. get_effective_sla()
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
-- 15. set_ticket_sla_deadline() + trigger
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
-- 16. handle_new_user() — processes pending invitations
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _invitation RECORD;
  _user_id uuid;
BEGIN
  SELECT * INTO _invitation
  FROM public.organization_invitations
  WHERE email = NEW.email
    AND status = 'pending'
    AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;

  INSERT INTO public.users (id, email, full_name, username, organization_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    _invitation.organization_id
  )
  RETURNING id INTO _user_id;

  IF _invitation.id IS NOT NULL THEN
    INSERT INTO public.organization_members (organization_id, user_id, role_id)
    VALUES (_invitation.organization_id, _user_id, _invitation.role_id);

    UPDATE public.organization_invitations
    SET status = 'accepted', accepted_at = now()
    WHERE id = _invitation.id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
