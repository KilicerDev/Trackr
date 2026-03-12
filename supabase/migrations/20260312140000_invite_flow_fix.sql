-- ============================================
-- Fix: handle_new_user() should NOT auto-approve invited users.
-- The user row is still created (with organization_id from the invitation),
-- but organization_members insertion and invitation acceptance are deferred
-- until the user explicitly calls accept_invitation() after setting a password.
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _invitation RECORD;
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
  );

  RETURN NEW;
END;
$$;


-- ============================================
-- New function: accept_invitation()
-- Called by the invited user after they set their password.
-- Uses auth.uid() to look up the user, finds their pending invitation,
-- inserts into organization_members, and marks the invitation accepted.
-- ============================================

CREATE OR REPLACE FUNCTION public.accept_invitation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user RECORD;
  _invitation RECORD;
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

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_invitation() TO authenticated;
