-- ============================================
-- MIGRATION: Add missing INSERT policy + fix SELECT for organizations
-- ============================================

-- 1. Allow owners to INSERT new organizations
CREATE POLICY "organizations_insert"
  ON public.organizations FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );

-- 2. Broaden SELECT so owners can see ALL orgs (not just those they belong to)
DROP POLICY "organizations_select" ON public.organizations;

CREATE POLICY "organizations_select"
  ON public.organizations FOR SELECT
  TO authenticated
  USING (
    public.is_member_of(id)
    OR EXISTS (
      SELECT 1 FROM public.organization_members om
      JOIN public.roles r ON r.id = om.role_id
      WHERE om.user_id = auth.uid() AND r.slug = 'owner' AND r.is_system = true
    )
  );
