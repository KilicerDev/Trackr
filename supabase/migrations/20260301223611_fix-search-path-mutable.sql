-- ============================================
-- MIGRATION: Fix mutable search_path on all functions
-- ============================================

-- 1. authorize
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


-- 2. is_member_of
CREATE OR REPLACE FUNCTION public.is_member_of(
  _org_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = _org_id
      AND user_id = auth.uid()
  );
$$;


-- 3. project_org_id
CREATE OR REPLACE FUNCTION public.project_org_id(_project_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT organization_id FROM public.projects WHERE id = _project_id;
$$;


-- 4. task_org_id
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


-- 5. ticket_org_id
CREATE OR REPLACE FUNCTION public.ticket_org_id(_ticket_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT organization_id FROM public.support_tickets WHERE id = _ticket_id;
$$;


-- 6. is_task_owner
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


-- 7. user_has_permission (from init migration)
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
BEGIN
  SELECT om.role_id INTO _role_id
  FROM public.organization_members om
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;

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


-- 8. get_user_role
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
BEGIN
  RETURN QUERY
  SELECT r.id, r.slug, r.name
  FROM public.organization_members om
  JOIN public.roles r ON r.id = om.role_id
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;
END;
$$;


-- 9. get_user_permissions
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


-- 10. handle_updated_at
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


-- 11. handle_new_user (if you created it)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;