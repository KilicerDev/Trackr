-- accept_invitation() now returns the accepted role's slug so the client
-- can pick the correct landing page (e.g. /c for client roles) without
-- relying on stale data captured before the membership row existed.

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

  SELECT slug INTO _role_slug
  FROM public.roles
  WHERE id = _invitation.role_id;

  RETURN jsonb_build_object('success', true, 'role_slug', _role_slug);
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_invitation() TO authenticated;
