-- ============================================
-- NOTIFICATIONS: Trigger functions and triggers
-- ============================================


-- ============================================
-- 1. CORE HELPER: insert_notification()
-- ============================================

CREATE OR REPLACE FUNCTION public.insert_notification(
  _org_id        uuid,
  _recipient_id  uuid,
  _actor_id      uuid,
  _type          public.notification_type,
  _title         text,
  _body          text,
  _resource_type text,
  _resource_id   uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _enabled boolean;
BEGIN
  IF _actor_id IS NOT NULL AND _actor_id = _recipient_id THEN
    RETURN;
  END IF;

  IF _type != 'sla_breach' THEN
    SELECT CASE _type
      WHEN 'ticket_created'     THEN os.notify_on_ticket_created
      WHEN 'ticket_assigned'    THEN os.notify_on_ticket_assigned
      WHEN 'ticket_resolved'    THEN os.notify_on_ticket_resolved
      WHEN 'ticket_message'     THEN os.notify_on_comment
      WHEN 'task_assigned'      THEN os.notify_on_task_assigned
      WHEN 'task_status_change' THEN os.notify_on_task_status_change
      WHEN 'task_comment'       THEN os.notify_on_comment
    END INTO _enabled
    FROM public.organization_settings os
    WHERE os.organization_id = _org_id;

    IF _enabled IS NULL THEN _enabled := true; END IF;
    IF NOT _enabled THEN RETURN; END IF;
  END IF;

  INSERT INTO public.notifications (
    organization_id, recipient_id, actor_id, type,
    title, body, resource_type, resource_id
  ) VALUES (
    _org_id, _recipient_id, _actor_id, _type,
    _title, _body, _resource_type, _resource_id
  );
END;
$$;


-- ============================================
-- 2. Ticket created
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_ticket_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _actor_id uuid;
  _r        record;
BEGIN
  _actor_id := auth.uid();

  FOR _r IN
    SELECT DISTINCT om.user_id
    FROM public.organization_members om
    JOIN public.role_permissions rp ON rp.role_id = om.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE om.organization_id = NEW.organization_id
      AND p.resource = 'support_tickets'
      AND p.action   = 'read'
      AND rp.scope   = 'all'
  LOOP
    PERFORM public.insert_notification(
      NEW.organization_id, _r.user_id, _actor_id,
      'ticket_created',
      'New ticket: ' || NEW.subject, NULL,
      'ticket', NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_ticket_created
  AFTER INSERT ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_ticket_created();


-- ============================================
-- 3. Ticket assigned
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_ticket_assigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.assigned_agent_id IS NOT NULL
     AND NEW.assigned_agent_id IS DISTINCT FROM OLD.assigned_agent_id
  THEN
    PERFORM public.insert_notification(
      NEW.organization_id, NEW.assigned_agent_id, auth.uid(),
      'ticket_assigned',
      'Ticket assigned to you', NEW.subject,
      'ticket', NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_ticket_assigned
  AFTER UPDATE OF assigned_agent_id ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_ticket_assigned();


-- ============================================
-- 4. Ticket resolved
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_ticket_resolved()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'resolved' AND OLD.status IS DISTINCT FROM 'resolved' THEN
    PERFORM public.insert_notification(
      NEW.organization_id, NEW.customer_id, auth.uid(),
      'ticket_resolved',
      'Your ticket has been resolved', NEW.subject,
      'ticket', NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_ticket_resolved
  AFTER UPDATE OF status ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_ticket_resolved();


-- ============================================
-- 5. Ticket message
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_ticket_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _ticket       record;
  _participants uuid[];
  _p            uuid;
BEGIN
  SELECT t.organization_id, t.customer_id, t.assigned_agent_id, t.subject
  INTO _ticket
  FROM public.support_tickets t
  WHERE t.id = NEW.ticket_id;

  IF _ticket IS NULL THEN RETURN NEW; END IF;

  _participants := ARRAY[]::uuid[];

  IF NOT NEW.is_internal_note AND _ticket.customer_id IS NOT NULL THEN
    _participants := array_append(_participants, _ticket.customer_id);
  END IF;

  IF _ticket.assigned_agent_id IS NOT NULL
     AND NOT (_ticket.assigned_agent_id = ANY(_participants))
  THEN
    _participants := array_append(_participants, _ticket.assigned_agent_id);
  END IF;

  FOREACH _p IN ARRAY _participants LOOP
    PERFORM public.insert_notification(
      _ticket.organization_id, _p, NEW.sender_id,
      'ticket_message',
      'New message on ticket', _ticket.subject,
      'ticket', NEW.ticket_id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_ticket_message
  AFTER INSERT ON public.support_ticket_messages
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_ticket_message();


-- ============================================
-- 6. Task assigned
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_task_assigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _task record;
BEGIN
  SELECT t.title, p.organization_id
  INTO _task
  FROM public.tasks t
  JOIN public.projects p ON p.id = t.project_id
  WHERE t.id = NEW.task_id;

  IF _task IS NULL THEN RETURN NEW; END IF;

  PERFORM public.insert_notification(
    _task.organization_id, NEW.user_id, NEW.assigned_by,
    'task_assigned',
    'Task assigned to you', _task.title,
    'task', NEW.task_id
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_task_assigned
  AFTER INSERT ON public.task_assignments
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_task_assigned();


-- ============================================
-- 7. Task status change
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _task record;
  _r    record;
BEGIN
  IF NEW.field_name IS NULL OR NEW.field_name != 'status' THEN
    RETURN NEW;
  END IF;

  SELECT t.title, t.created_by, p.organization_id
  INTO _task
  FROM public.tasks t
  JOIN public.projects p ON p.id = t.project_id
  WHERE t.id = NEW.task_id;

  IF _task IS NULL THEN RETURN NEW; END IF;

  PERFORM public.insert_notification(
    _task.organization_id, _task.created_by, NEW.user_id,
    'task_status_change',
    'Task status changed to ' || COALESCE(NEW.new_value, 'unknown'),
    _task.title,
    'task', NEW.task_id
  );

  FOR _r IN
    SELECT DISTINCT ta.user_id
    FROM public.task_assignments ta
    WHERE ta.task_id = NEW.task_id
      AND ta.user_id != _task.created_by
  LOOP
    PERFORM public.insert_notification(
      _task.organization_id, _r.user_id, NEW.user_id,
      'task_status_change',
      'Task status changed to ' || COALESCE(NEW.new_value, 'unknown'),
      _task.title,
      'task', NEW.task_id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_task_status_change
  AFTER INSERT ON public.task_activities
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_task_status_change();


-- ============================================
-- 8. Task comment
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_task_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _task record;
  _r    record;
BEGIN
  SELECT t.title, t.created_by, p.organization_id
  INTO _task
  FROM public.tasks t
  JOIN public.projects p ON p.id = t.project_id
  WHERE t.id = NEW.task_id;

  IF _task IS NULL THEN RETURN NEW; END IF;

  PERFORM public.insert_notification(
    _task.organization_id, _task.created_by, NEW.user_id,
    'task_comment',
    'New comment on task', _task.title,
    'task', NEW.task_id
  );

  FOR _r IN
    SELECT DISTINCT ta.user_id
    FROM public.task_assignments ta
    WHERE ta.task_id = NEW.task_id
      AND ta.user_id != _task.created_by
  LOOP
    PERFORM public.insert_notification(
      _task.organization_id, _r.user_id, NEW.user_id,
      'task_comment',
      'New comment on task', _task.title,
      'task', NEW.task_id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_task_comment
  AFTER INSERT ON public.task_comments
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_task_comment();


-- ============================================
-- 9. SLA breach
-- ============================================

CREATE OR REPLACE FUNCTION public.trg_notify_sla_breach()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _ticket record;
  _r      record;
BEGIN
  SELECT t.organization_id, t.assigned_agent_id, t.subject
  INTO _ticket
  FROM public.support_tickets t
  WHERE t.id = NEW.ticket_id;

  IF _ticket IS NULL THEN RETURN NEW; END IF;

  IF _ticket.assigned_agent_id IS NOT NULL THEN
    PERFORM public.insert_notification(
      _ticket.organization_id, _ticket.assigned_agent_id, NULL,
      'sla_breach',
      'SLA ' || NEW.breach_type || ' breach', _ticket.subject,
      'ticket', NEW.ticket_id
    );
  END IF;

  FOR _r IN
    SELECT DISTINCT om.user_id
    FROM public.organization_members om
    JOIN public.roles r ON r.id = om.role_id
    WHERE om.organization_id = _ticket.organization_id
      AND r.slug IN ('owner', 'admin')
      AND r.is_system = true
      AND om.user_id IS DISTINCT FROM _ticket.assigned_agent_id
  LOOP
    PERFORM public.insert_notification(
      _ticket.organization_id, _r.user_id, NULL,
      'sla_breach',
      'SLA ' || NEW.breach_type || ' breach', _ticket.subject,
      'ticket', NEW.ticket_id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_sla_breach
  AFTER INSERT ON public.sla_breaches
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_sla_breach();


-- ============================================
-- 10. SOFT-DELETE CLEANUP
-- ============================================

CREATE OR REPLACE FUNCTION public.cleanup_notifications_on_soft_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    DELETE FROM public.notifications
    WHERE resource_type = TG_ARGV[0]
      AND resource_id  = OLD.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cleanup_notifications_task
  AFTER UPDATE OF deleted_at ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_notifications_on_soft_delete('task');

CREATE TRIGGER trg_cleanup_notifications_ticket
  AFTER UPDATE OF deleted_at ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_notifications_on_soft_delete('ticket');
