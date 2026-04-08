-- ============================================================
-- Activity logging: auto-track field changes on tasks & tickets
-- ============================================================

-- 0. Extend activity_action enum with commented / messaged
ALTER TYPE public.activity_action ADD VALUE IF NOT EXISTS 'commented';
ALTER TYPE public.activity_action ADD VALUE IF NOT EXISTS 'messaged';

-- 1. Enum for ticket activity fields
CREATE TYPE public.ticket_activity_field AS ENUM (
  'status', 'priority', 'category', 'assigned_agent_id',
  'subject', 'description', 'channel'
);

-- 2. Ticket activities table (mirrors task_activities)
CREATE TABLE public.ticket_activities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id   uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  action      public.activity_action NOT NULL,
  field_name  public.ticket_activity_field,
  old_value   text,
  new_value   text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ticket_activities_ticket_id   ON public.ticket_activities (ticket_id);
CREATE INDEX idx_ticket_activities_user_id     ON public.ticket_activities (user_id);
CREATE INDEX idx_ticket_activities_created_at  ON public.ticket_activities (created_at);

ALTER TABLE public.ticket_activities ENABLE ROW LEVEL SECURITY;

-- RLS: read if you can read tickets in that org
CREATE POLICY "ticket_activities_select"
  ON public.ticket_activities FOR SELECT
  TO authenticated
  USING (
    public.authorize(
      'support_tickets', 'read',
      (SELECT organization_id FROM public.support_tickets WHERE id = ticket_id)
    )
  );

-- Only triggers insert, never direct API
CREATE POLICY "ticket_activities_insert"
  ON public.ticket_activities FOR INSERT
  TO authenticated
  WITH CHECK (false);

-- 3. Task update trigger — auto-log field changes
CREATE OR REPLACE FUNCTION public.trg_log_task_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_id uuid;
  _fields  text[] := ARRAY[
    'status', 'priority', 'type', 'title', 'description',
    'project_id', 'parent_id', 'milestone_id', 'environment',
    'start_at', 'end_at'
  ];
  _f       text;
  _old_val text;
  _new_val text;
BEGIN
  _user_id := auth.uid();

  -- Log soft-delete as 'deleted' action
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    INSERT INTO public.task_activities (task_id, user_id, action)
    VALUES (NEW.id, _user_id, 'deleted');
    RETURN NEW;
  END IF;

  -- Skip undelete or other deleted_at changes
  IF OLD.deleted_at IS DISTINCT FROM NEW.deleted_at THEN
    RETURN NEW;
  END IF;

  FOREACH _f IN ARRAY _fields LOOP
    EXECUTE format(
      'SELECT ($1).%I::text, ($2).%I::text', _f, _f
    ) INTO _old_val, _new_val USING OLD, NEW;

    IF _old_val IS DISTINCT FROM _new_val THEN
      INSERT INTO public.task_activities
        (task_id, user_id, action, field_name, old_value, new_value)
      VALUES
        (NEW.id, _user_id, 'updated_field', _f::public.activity_field, _old_val, _new_val);
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_task_changes
  AFTER UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_task_changes();

-- Task created trigger
CREATE OR REPLACE FUNCTION public.trg_log_task_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.task_activities (task_id, user_id, action)
  VALUES (NEW.id, COALESCE(auth.uid(), NEW.created_by), 'created');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_task_created
  AFTER INSERT ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_task_created();

-- Task assignment triggers
CREATE OR REPLACE FUNCTION public.trg_log_task_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_name text;
BEGIN
  SELECT full_name INTO _user_name FROM public.users WHERE id =
    CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.task_activities
      (task_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.task_id, COALESCE(auth.uid(), NEW.assigned_by), 'updated_field',
       'assignee_id', NULL, COALESCE(_user_name, NEW.user_id::text));
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.task_activities
      (task_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (OLD.task_id, COALESCE(auth.uid(), OLD.assigned_by), 'updated_field',
       'assignee_id', COALESCE(_user_name, OLD.user_id::text), NULL);
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_log_task_assignment
  AFTER INSERT OR DELETE ON public.task_assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_task_assignment();

-- 4. Ticket update trigger — auto-log field changes
CREATE OR REPLACE FUNCTION public.trg_log_ticket_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_id uuid;
  _fields  text[] := ARRAY[
    'status', 'priority', 'category', 'assigned_agent_id',
    'subject', 'description', 'channel'
  ];
  _f       text;
  _old_val text;
  _new_val text;
BEGIN
  _user_id := auth.uid();

  -- Log soft-delete
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    INSERT INTO public.ticket_activities (ticket_id, user_id, action)
    VALUES (NEW.id, _user_id, 'deleted');
    RETURN NEW;
  END IF;

  IF OLD.deleted_at IS DISTINCT FROM NEW.deleted_at THEN
    RETURN NEW;
  END IF;

  FOREACH _f IN ARRAY _fields LOOP
    EXECUTE format(
      'SELECT ($1).%I::text, ($2).%I::text', _f, _f
    ) INTO _old_val, _new_val USING OLD, NEW;

    IF _old_val IS DISTINCT FROM _new_val THEN
      INSERT INTO public.ticket_activities
        (ticket_id, user_id, action, field_name, old_value, new_value)
      VALUES
        (NEW.id, _user_id, 'updated_field', _f::public.ticket_activity_field, _old_val, _new_val);
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_ticket_changes
  AFTER UPDATE ON public.support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_ticket_changes();

-- Ticket created trigger
CREATE OR REPLACE FUNCTION public.trg_log_ticket_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.ticket_activities (ticket_id, user_id, action)
  VALUES (NEW.id, COALESCE(auth.uid(), NEW.customer_id), 'created');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_ticket_created
  AFTER INSERT ON public.support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_ticket_created();

-- Task comment trigger
CREATE OR REPLACE FUNCTION public.trg_log_task_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.task_activities
    (task_id, user_id, action, new_value)
  VALUES
    (NEW.task_id, NEW.user_id, 'commented',
     CASE WHEN length(NEW.content) > 120 THEN left(NEW.content, 120) || '…' ELSE NEW.content END);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_task_comment
  AFTER INSERT ON public.task_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_task_comment();

-- Ticket message trigger
CREATE OR REPLACE FUNCTION public.trg_log_ticket_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.ticket_activities
    (ticket_id, user_id, action, new_value)
  VALUES
    (NEW.ticket_id, NEW.sender_id, 'messaged',
     CASE WHEN length(NEW.body) > 120 THEN left(NEW.body, 120) || '…' ELSE NEW.body END);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_ticket_message
  AFTER INSERT ON public.support_ticket_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_ticket_message();

-- 5. Unified admin activity log RPC
CREATE OR REPLACE FUNCTION public.get_admin_activity_log(
  _type   text DEFAULT 'all',
  _limit  int  DEFAULT 25,
  _offset int  DEFAULT 0
)
RETURNS TABLE (
  id               uuid,
  source_type      text,
  source_id        uuid,
  source_label     text,
  source_project_id uuid,
  user_id          uuid,
  user_name        text,
  user_avatar      text,
  action           public.activity_action,
  field_name       text,
  old_value        text,
  new_value        text,
  created_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM (
    SELECT
      ta.id,
      'task'::text       AS source_type,
      ta.task_id         AS source_id,
      COALESCE(t.short_id, t.title) AS source_label,
      t.project_id       AS source_project_id,
      ta.user_id,
      u.full_name        AS user_name,
      u.avatar_url       AS user_avatar,
      ta.action,
      ta.field_name::text,
      ta.old_value,
      ta.new_value,
      ta.created_at
    FROM public.task_activities ta
    JOIN public.users u ON u.id = ta.user_id
    JOIN public.tasks t ON t.id = ta.task_id
    WHERE (_type = 'all' OR _type = 'task')

    UNION ALL

    SELECT
      tka.id,
      'ticket'::text     AS source_type,
      tka.ticket_id      AS source_id,
      st.subject         AS source_label,
      NULL::uuid         AS source_project_id,
      tka.user_id,
      u.full_name        AS user_name,
      u.avatar_url       AS user_avatar,
      tka.action,
      tka.field_name::text,
      tka.old_value,
      tka.new_value,
      tka.created_at
    FROM public.ticket_activities tka
    JOIN public.users u ON u.id = tka.user_id
    JOIN public.support_tickets st ON st.id = tka.ticket_id
    WHERE (_type = 'all' OR _type = 'ticket')
  ) combined
  ORDER BY created_at DESC
  LIMIT _limit
  OFFSET _offset;
END;
$$;

-- 6. Count companion for pagination
CREATE OR REPLACE FUNCTION public.get_admin_activity_log_count(
  _type text DEFAULT 'all'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
  _count bigint := 0;
  _tc    bigint;
  _tkc   bigint;
BEGIN
  IF _type = 'all' OR _type = 'task' THEN
    SELECT count(*) INTO _tc FROM public.task_activities;
    _count := _count + _tc;
  END IF;
  IF _type = 'all' OR _type = 'ticket' THEN
    SELECT count(*) INTO _tkc FROM public.ticket_activities;
    _count := _count + _tkc;
  END IF;
  RETURN _count;
END;
$$;
