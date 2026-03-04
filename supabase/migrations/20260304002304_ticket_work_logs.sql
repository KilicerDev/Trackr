-- ============================================
-- MIGRATION: Ticket Work Logs (hours tracking)
-- ============================================

CREATE TABLE public.ticket_work_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id   uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  minutes     int NOT NULL CHECK (minutes > 0),
  description text,
  logged_at   date NOT NULL DEFAULT CURRENT_DATE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ticket_work_logs ENABLE ROW LEVEL SECURITY;

-- SELECT: can read if can read the parent ticket
CREATE POLICY "ticket_work_logs_select"
  ON public.ticket_work_logs FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'support_tickets', 'read',
      public.ticket_org_id(ticket_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.support_tickets t
        WHERE t.id = ticket_id
          AND (t.customer_id = auth.uid() OR t.assigned_agent_id = auth.uid())
      )
    )
  );

-- INSERT: can insert if can read the ticket, must be own user_id
CREATE POLICY "ticket_work_logs_insert"
  ON public.ticket_work_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize(
      'support_tickets', 'read',
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

-- DELETE: own entries OR has support_tickets delete permission
CREATE POLICY "ticket_work_logs_delete"
  ON public.ticket_work_logs FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.authorize('support_tickets', 'delete', public.ticket_org_id(ticket_id))
  );

CREATE INDEX idx_ticket_work_logs_ticket_user
  ON public.ticket_work_logs (ticket_id, user_id);


-- ============================================
-- Task Work Logs (hours tracking for tasks)
-- ============================================

CREATE TABLE public.task_work_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  minutes     int NOT NULL CHECK (minutes > 0),
  description text,
  logged_at   date NOT NULL DEFAULT CURRENT_DATE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.task_work_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_work_logs_select"
  ON public.task_work_logs FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.task_assignments ta
        WHERE ta.task_id = task_work_logs.task_id
          AND ta.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "task_work_logs_insert"
  ON public.task_work_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    public.authorize(
      'tasks', 'read',
      public.task_org_id(task_id),
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.task_assignments ta
        WHERE ta.task_id = task_work_logs.task_id
          AND ta.user_id = auth.uid()
      )
    )
    AND user_id = auth.uid()
  );

CREATE POLICY "task_work_logs_delete"
  ON public.task_work_logs FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.authorize('tasks', 'delete', public.task_org_id(task_id))
  );

CREATE INDEX idx_task_work_logs_task_user
  ON public.task_work_logs (task_id, user_id);
