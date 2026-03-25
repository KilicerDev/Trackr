-- ============================================
-- EMAIL NOTIFICATIONS
-- Sends emails via Go email microservice when
-- in-app notifications are created.
--
-- Uses LISTEN/NOTIFY instead of pg_net so the
-- Go service just connects to the DB directly.
-- No HTTP networking issues between containers.
-- ============================================


-- 1. User-level opt-out
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS email_notifications_enabled boolean NOT NULL DEFAULT true;


-- 2. Trigger function: sends a NOTIFY with the email payload as JSON
CREATE OR REPLACE FUNCTION public.trg_send_email_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _recipient       record;
  _actor_name      text;
  _content_preview text;
  _payload         jsonb;
BEGIN
  -- Look up recipient
  SELECT u.email, u.full_name, u.email_notifications_enabled
  INTO _recipient
  FROM public.users u
  WHERE u.id = NEW.recipient_id
    AND u.deleted_at IS NULL;

  -- Skip if user not found or email notifications disabled
  IF _recipient IS NULL OR NOT _recipient.email_notifications_enabled THEN
    RETURN NEW;
  END IF;

  -- Look up actor name
  IF NEW.actor_id IS NOT NULL THEN
    SELECT u.full_name INTO _actor_name
    FROM public.users u
    WHERE u.id = NEW.actor_id;
  END IF;

  -- Look up content preview for comments and messages
  IF NEW.type = 'task_comment' AND NEW.resource_id IS NOT NULL AND NEW.actor_id IS NOT NULL THEN
    SELECT LEFT(tc.content, 300) INTO _content_preview
    FROM public.task_comments tc
    WHERE tc.task_id = NEW.resource_id
      AND tc.user_id = NEW.actor_id
    ORDER BY tc.created_at DESC
    LIMIT 1;
  ELSIF NEW.type = 'ticket_message' AND NEW.resource_id IS NOT NULL AND NEW.actor_id IS NOT NULL THEN
    SELECT LEFT(stm.body, 300) INTO _content_preview
    FROM public.support_ticket_messages stm
    WHERE stm.ticket_id = NEW.resource_id
      AND stm.sender_id = NEW.actor_id
      AND stm.deleted_at IS NULL
    ORDER BY stm.created_at DESC
    LIMIT 1;
  END IF;

  -- Build payload and notify
  _payload := jsonb_build_object(
    'notification_id', NEW.id,
    'recipient_email', _recipient.email,
    'recipient_name',  _recipient.full_name,
    'actor_name',      _actor_name,
    'type',            NEW.type,
    'title',           NEW.title,
    'body',            NEW.body,
    'resource_type',   NEW.resource_type,
    'resource_id',     NEW.resource_id,
    'content_preview', _content_preview
  );

  PERFORM pg_notify('email_notification', _payload::text);

  RETURN NEW;
END;
$$;


-- 3. Attach trigger
CREATE TRIGGER trg_send_email_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_send_email_notification();
