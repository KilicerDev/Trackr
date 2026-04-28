-- Allow platform members to create "global custom roles" — roles with
-- organization_id IS NULL and is_system = false. These are usable by every
-- organization (visible in role pickers everywhere) but only platform staff
-- can create, edit, or delete them. System roles still keep is_system = true.

DROP POLICY IF EXISTS "roles_select" ON public.roles;
CREATE POLICY "roles_select"
  ON public.roles FOR SELECT
  TO authenticated
  USING (
    is_system = true
    OR organization_id IS NULL
    OR public.is_member_of(organization_id)
  );

DROP POLICY IF EXISTS "roles_insert" ON public.roles;
CREATE POLICY "roles_insert"
  ON public.roles FOR INSERT
  TO authenticated
  WITH CHECK (
    (
      organization_id IS NOT NULL
      AND public.authorize('members', 'manage_roles', organization_id)
    )
    OR (
      organization_id IS NULL
      AND is_system = false
      AND public.is_platform_member(auth.uid())
    )
  );

DROP POLICY IF EXISTS "roles_update" ON public.roles;
CREATE POLICY "roles_update"
  ON public.roles FOR UPDATE
  TO authenticated
  USING (
    is_system = false
    AND (
      (
        organization_id IS NOT NULL
        AND public.authorize('members', 'manage_roles', organization_id)
      )
      OR (
        organization_id IS NULL
        AND public.is_platform_member(auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS "roles_delete" ON public.roles;
CREATE POLICY "roles_delete"
  ON public.roles FOR DELETE
  TO authenticated
  USING (
    is_system = false
    AND (
      (
        organization_id IS NOT NULL
        AND public.authorize('members', 'manage_roles', organization_id)
      )
      OR (
        organization_id IS NULL
        AND public.is_platform_member(auth.uid())
      )
    )
  );

-- role_permissions: same expansion so platform staff can manage permissions
-- on global custom roles.

DROP POLICY IF EXISTS "role_permissions_insert" ON public.role_permissions;
CREATE POLICY "role_permissions_insert"
  ON public.role_permissions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND r.is_system = false
        AND (
          (
            r.organization_id IS NOT NULL
            AND public.authorize('members', 'manage_roles', r.organization_id)
          )
          OR (
            r.organization_id IS NULL
            AND public.is_platform_member(auth.uid())
          )
        )
    )
  );

DROP POLICY IF EXISTS "role_permissions_update" ON public.role_permissions;
CREATE POLICY "role_permissions_update"
  ON public.role_permissions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND r.is_system = false
        AND (
          (
            r.organization_id IS NOT NULL
            AND public.authorize('members', 'manage_roles', r.organization_id)
          )
          OR (
            r.organization_id IS NULL
            AND public.is_platform_member(auth.uid())
          )
        )
    )
  );

DROP POLICY IF EXISTS "role_permissions_delete" ON public.role_permissions;
CREATE POLICY "role_permissions_delete"
  ON public.role_permissions FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND r.is_system = false
        AND (
          (
            r.organization_id IS NOT NULL
            AND public.authorize('members', 'manage_roles', r.organization_id)
          )
          OR (
            r.organization_id IS NULL
            AND public.is_platform_member(auth.uid())
          )
        )
    )
  );
