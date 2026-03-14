-- Flip ticket-task relationship: tasks now point to tickets (many tasks per ticket)

-- Add support_ticket_id FK to tasks
ALTER TABLE public.tasks
  ADD COLUMN support_ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE SET NULL;

-- Index for efficient lookups
CREATE INDEX idx_tasks_support_ticket_id ON public.tasks(support_ticket_id);

-- Drop the unused related_task_id column from support_tickets
ALTER TABLE public.support_tickets
  DROP COLUMN IF EXISTS related_task_id;
