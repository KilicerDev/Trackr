-- Surface the role's `is_system` flag through get_user_role and
-- accept_invitation so the app can route every non-system role (custom
-- per-org or global) to the client area at /c, the same place the system
-- "client" role already lands.

DROP FUNCTION IF EXISTS public.get_user_role(uuid, uuid);

CREATE FUNCTION public.get_user_role(
  _user_id         uuid,
  _organization_id uuid
)
RETURNS TABLE (
  role_id   uuid,
  role_slug text,
  role_name text,
  is_system boolean
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

  IF _platform_org_id IS NOT NULL THEN
    RETURN QUERY
    SELECT r.id, r.slug, r.name, r.is_system
    FROM public.organization_members om
    JOIN public.roles r ON r.id = om.role_id
    WHERE om.organization_id = _platform_org_id
      AND om.user_id = _user_id;

    IF FOUND THEN RETURN; END IF;
  END IF;

  RETURN QUERY
  SELECT r.id, r.slug, r.name, r.is_system
  FROM public.organization_members om
  JOIN public.roles r ON r.id = om.role_id
  WHERE om.organization_id = _organization_id
    AND om.user_id = _user_id;
END;
$$;


CREATE OR REPLACE FUNCTION public.accept_invitation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user RECORD;
  _invitation RECORD;
  _role_slug text;
  _role_is_system boolean;
BEGIN
  SELECT * INTO _user
  FROM public.users
  WHERE id = auth.uid();

  IF _user.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  SELECT * INTO _invitation
  FROM public.organization_invitations
  WHERE email = _user.email
    AND status = 'pending'
    AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;

  IF _invitation.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No pending invitation found');
  END IF;

  INSERT INTO public.organization_members (organization_id, user_id, role_id)
  VALUES (_invitation.organization_id, _user.id, _invitation.role_id);

  UPDATE public.organization_invitations
  SET status = 'accepted', accepted_at = now()
  WHERE id = _invitation.id;

  SELECT slug, is_system INTO _role_slug, _role_is_system
  FROM public.roles
  WHERE id = _invitation.role_id;

  RETURN jsonb_build_object(
    'success', true,
    'role_slug', _role_slug,
    'role_is_system', _role_is_system
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_invitation() TO authenticated;
