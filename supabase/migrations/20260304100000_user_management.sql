-- ============================================
-- MIGRATION: User Management
--
-- 1. organization_invitations table + RLS
-- 2. Update handle_new_user() to process pending invites
-- 3. Create trigger on auth.users
-- 4. Broaden users_select so platform org members see all users
-- ============================================


-- ============================================
-- 1. ORGANIZATION INVITATIONS TABLE
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

ALTER TABLE public.organization_invitations ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_invitations_org_id ON public.organization_invitations (organization_id);
CREATE INDEX idx_invitations_email ON public.organization_invitations (email);
CREATE INDEX idx_invitations_status ON public.organization_invitations (status) WHERE status = 'pending';

-- SELECT: org members can view invitations
CREATE POLICY "invitations_select"
  ON public.organization_invitations FOR SELECT
  TO authenticated
  USING (public.is_member_of(organization_id));

-- INSERT: users with members.invite permission
CREATE POLICY "invitations_insert"
  ON public.organization_invitations FOR INSERT
  TO authenticated
  WITH CHECK (public.authorize('members', 'invite', organization_id));

-- UPDATE: users with members.invite permission (for revoking)
CREATE POLICY "invitations_update"
  ON public.organization_invitations FOR UPDATE
  TO authenticated
  USING (public.authorize('members', 'invite', organization_id));

-- DELETE: users with members.invite permission
CREATE POLICY "invitations_delete"
  ON public.organization_invitations FOR DELETE
  TO authenticated
  USING (public.authorize('members', 'invite', organization_id));


-- ============================================
-- 2. UPDATE handle_new_user() TO PROCESS INVITATIONS
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
  -- Check for a pending invitation for this email
  SELECT * INTO _invitation
  FROM public.organization_invitations
  WHERE email = NEW.email
    AND status = 'pending'
    AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;

  -- Insert the public.users row
  INSERT INTO public.users (id, email, full_name, username, organization_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    _invitation.organization_id  -- NULL if no invitation
  )
  RETURNING id INTO _user_id;

  -- If there was a pending invitation, create the membership and accept the invite
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


-- ============================================
-- 3. CREATE TRIGGER ON auth.users
-- ============================================

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- ============================================
-- 4. BROADEN users_select FOR PLATFORM ORG MEMBERS
-- ============================================

DROP POLICY "users_select" ON public.users;

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
    OR EXISTS (
      SELECT 1 FROM public.system_config sc
      JOIN public.organization_members om
        ON om.organization_id = sc.platform_organization_id
      WHERE om.user_id = auth.uid()
    )
  );


-- ============================================
-- 5. ALLOW ADMINS TO UPDATE OTHER USERS
-- ============================================

DROP POLICY "users_update" ON public.users;

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
