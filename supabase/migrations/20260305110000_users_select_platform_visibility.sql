-- ============================================
-- FIX: Allow all authenticated users to see platform org members
--
-- The existing policy lets platform members see everyone, but not
-- the inverse. When a platform agent replies to a client's ticket,
-- the client can't resolve the sender's name because their user
-- row belongs to the platform org, which the client isn't a member of.
--
-- The check must use a SECURITY DEFINER function because the
-- inline subquery in the policy runs under the caller's RLS
-- context, and clients can't see organization_members rows for
-- the platform org.
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
    OR public.is_platform_member(auth.uid())
    -- All authenticated users can see platform org members (support team)
    OR public.is_platform_member(id)
  );
