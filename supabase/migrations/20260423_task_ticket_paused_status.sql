-- Add 'paused' value to task_status and ticket_status enums so work items
-- can be parked without moving them to cancelled/done.

ALTER TYPE public.task_status ADD VALUE IF NOT EXISTS 'paused' AFTER 'in_progress';
ALTER TYPE public.ticket_status ADD VALUE IF NOT EXISTS 'paused' AFTER 'in_progress';
