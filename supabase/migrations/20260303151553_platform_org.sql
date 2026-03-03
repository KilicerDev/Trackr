-- ============================================
-- MIGRATION: Separate Platform Org from Client Orgs
--
-- Adds platform_organization_id to system_config so the platform
-- team's org is distinguishable from client organizations.
-- Updates all permission/role helper functions with
-- "platform-org-first" fallback: platform team members get
-- global access across all client orgs.
-- ============================================


-- ============================================
-- 1. ADD platform_organization_id TO system_config
-- ============================================

ALTER TABLE public.system_config
  ADD COLUMN platform_organization_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL;


-- ============================================
-- 2. authorize() — used by RLS policies
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
-- 3. is_member_of() — platform team members have implicit membership
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

  -- Platform team members have access to all orgs
  IF _platform_org_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.organization_members
      WHERE organization_id = _platform_org_id
        AND user_id = auth.uid()
    ) THEN
      RETURN true;
    END IF;
  END IF;

  -- Fall back to direct org membership
  RETURN EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = _org_id
      AND user_id = auth.uid()
  );
END;
$$;


-- ============================================
-- 4. user_has_permission()
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
-- 5. get_user_role()
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
-- 6. get_user_permissions()
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
