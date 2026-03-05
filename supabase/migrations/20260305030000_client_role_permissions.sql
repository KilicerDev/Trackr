-- ============================================
-- Remove support_tickets.update from client role
-- Clients should only create tickets and send messages, not edit ticket properties
-- ============================================

DELETE FROM public.role_permissions
WHERE role_id = 'a0000000-0000-0000-0000-000000000005'
  AND permission_id = (
    SELECT id FROM public.permissions
    WHERE resource = 'support_tickets' AND action = 'update'
  );


-- ============================================
-- Tighten ticket_work_logs INSERT policy
-- Require support_tickets.update (not just read) to log work
-- ============================================

DROP POLICY IF EXISTS "ticket_work_logs_insert" ON public.ticket_work_logs;

CREATE POLICY "ticket_work_logs_insert"
  ON public.ticket_work_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize(
      'support_tickets', 'update',
      public.ticket_org_id(ticket_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.support_tickets t
        WHERE t.id = ticket_id
          AND (t.customer_id = auth.uid() OR t.assigned_agent_id = auth.uid())
      )
    )
    AND user_id = auth.uid()
  );
