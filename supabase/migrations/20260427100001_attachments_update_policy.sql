-- ============================================
-- ATTACHMENTS: fix soft-delete + relax / clarify the UPDATE policy
--
-- Two related changes:
--
-- 1) The SELECT policy used to filter out rows where `deleted_at IS NOT NULL`.
--    On PG 17, an UPDATE that sets `deleted_at` makes the post-update row
--    invisible to the SELECT policy, which causes the UPDATE itself to fail
--    with "new row violates row-level security policy for table attachments".
--    Soft-delete via UPDATE is incompatible with putting the soft-delete
--    predicate inside the SELECT policy. We drop that predicate from the
--    policy; `attachments.list()` and other read paths already filter by
--    `.is('deleted_at', null)` at the API layer.
--
-- 2) The previous UPDATE policy was named `attachments_delete` with only a
--    `USING` clause (no explicit `WITH CHECK`) and was limited to the
--    uploader or holders of `tasks.delete`. We rename it to `attachments_update`,
--    spell out both `USING` and `WITH CHECK` (same expression), and also let
--    anyone who can update a task remove its attachments — Agents previously
--    couldn't, even on tasks they own.
-- ============================================

DROP POLICY IF EXISTS attachments_select ON public.attachments;
DROP POLICY IF EXISTS attachments_delete ON public.attachments;

CREATE POLICY attachments_select ON public.attachments
  FOR SELECT USING (
    public.is_member_of(org_id)
  );

CREATE POLICY attachments_update ON public.attachments
  FOR UPDATE
  USING (
    uploaded_by = auth.uid()
    OR public.authorize('tasks', 'delete', org_id)
    OR public.authorize('tasks', 'update', org_id)
  )
  WITH CHECK (
    uploaded_by = auth.uid()
    OR public.authorize('tasks', 'delete', org_id)
    OR public.authorize('tasks', 'update', org_id)
  );
