-- ============================================================
-- Wiki activity logging: auto-track changes on pages/folders/files
-- ============================================================

-- 1. Enums
CREATE TYPE public.wiki_activity_target AS ENUM ('page', 'folder', 'file');

CREATE TYPE public.wiki_activity_field AS ENUM (
  'title', 'content', 'name', 'file_name', 'folder_id', 'parent_id'
);

-- 2. Unified wiki_activities table (polymorphic target)
CREATE TABLE public.wiki_activities (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  target_type      public.wiki_activity_target NOT NULL,
  target_id        uuid NOT NULL,
  user_id          uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  action           public.activity_action NOT NULL,
  field_name       public.wiki_activity_field,
  old_value        text,
  new_value        text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_wiki_activities_target      ON public.wiki_activities (target_type, target_id);
CREATE INDEX idx_wiki_activities_user_id     ON public.wiki_activities (user_id);
CREATE INDEX idx_wiki_activities_created_at  ON public.wiki_activities (created_at);
CREATE INDEX idx_wiki_activities_org_id      ON public.wiki_activities (organization_id);

ALTER TABLE public.wiki_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wiki_activities_select"
  ON public.wiki_activities FOR SELECT
  TO authenticated
  USING (public.is_member_of(organization_id));

CREATE POLICY "wiki_activities_insert"
  ON public.wiki_activities FOR INSERT
  TO authenticated
  WITH CHECK (false);

-- Resolver helper: folder UUID → display name (or '(root)' for NULL)
CREATE OR REPLACE FUNCTION public.wiki_folder_label(_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN _id IS NULL THEN '(root)'
    ELSE COALESCE((SELECT name FROM public.wiki_folders WHERE id = _id), '(deleted folder)')
  END;
$$;

-- 3. wiki_pages triggers

CREATE OR REPLACE FUNCTION public.trg_log_wiki_page_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.wiki_activities
    (organization_id, target_type, target_id, user_id, action)
  VALUES
    (NEW.organization_id, 'page', NEW.id,
     COALESCE(auth.uid(), NEW.created_by), 'created');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_wiki_page_created
  AFTER INSERT ON public.wiki_pages
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_wiki_page_created();

CREATE OR REPLACE FUNCTION public.trg_log_wiki_page_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_id uuid;
BEGIN
  _user_id := COALESCE(auth.uid(), NEW.updated_by, NEW.created_by);

  -- Soft-delete
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action)
    VALUES (NEW.organization_id, 'page', NEW.id, _user_id, 'deleted');
    RETURN NEW;
  END IF;

  -- Ignore undelete or pure deleted_at toggles
  IF OLD.deleted_at IS DISTINCT FROM NEW.deleted_at THEN
    RETURN NEW;
  END IF;

  -- Title change
  IF OLD.title IS DISTINCT FROM NEW.title THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.organization_id, 'page', NEW.id, _user_id, 'updated_field',
       'title', OLD.title, NEW.title);
  END IF;

  -- Content change (don't store values — markdown can be huge)
  IF OLD.content IS DISTINCT FROM NEW.content THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name)
    VALUES
      (NEW.organization_id, 'page', NEW.id, _user_id, 'updated_field', 'content');
  END IF;

  -- Folder move — resolve UUIDs to folder names
  IF OLD.folder_id IS DISTINCT FROM NEW.folder_id THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.organization_id, 'page', NEW.id, _user_id, 'updated_field',
       'folder_id',
       public.wiki_folder_label(OLD.folder_id),
       public.wiki_folder_label(NEW.folder_id));
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_wiki_page_changes
  AFTER UPDATE ON public.wiki_pages
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_wiki_page_changes();

-- 4. wiki_folders triggers

CREATE OR REPLACE FUNCTION public.trg_log_wiki_folder_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.wiki_activities
    (organization_id, target_type, target_id, user_id, action)
  VALUES
    (NEW.organization_id, 'folder', NEW.id,
     COALESCE(auth.uid(), NEW.created_by), 'created');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_wiki_folder_created
  AFTER INSERT ON public.wiki_folders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_wiki_folder_created();

CREATE OR REPLACE FUNCTION public.trg_log_wiki_folder_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_id uuid;
BEGIN
  _user_id := COALESCE(auth.uid(), NEW.created_by);

  -- Soft-delete
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action)
    VALUES (NEW.organization_id, 'folder', NEW.id, _user_id, 'deleted');
    RETURN NEW;
  END IF;

  IF OLD.deleted_at IS DISTINCT FROM NEW.deleted_at THEN
    RETURN NEW;
  END IF;

  -- Name rename
  IF OLD.name IS DISTINCT FROM NEW.name THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.organization_id, 'folder', NEW.id, _user_id, 'updated_field',
       'name', OLD.name, NEW.name);
  END IF;

  -- Parent move
  IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.organization_id, 'folder', NEW.id, _user_id, 'updated_field',
       'parent_id',
       public.wiki_folder_label(OLD.parent_id),
       public.wiki_folder_label(NEW.parent_id));
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_wiki_folder_changes
  AFTER UPDATE ON public.wiki_folders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_wiki_folder_changes();

-- 5. wiki_files triggers

CREATE OR REPLACE FUNCTION public.trg_log_wiki_file_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.wiki_activities
    (organization_id, target_type, target_id, user_id, action)
  VALUES
    (NEW.organization_id, 'file', NEW.id,
     COALESCE(auth.uid(), NEW.uploaded_by), 'created');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_wiki_file_created
  AFTER INSERT ON public.wiki_files
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_wiki_file_created();

CREATE OR REPLACE FUNCTION public.trg_log_wiki_file_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_id uuid;
BEGIN
  _user_id := COALESCE(auth.uid(), NEW.uploaded_by);

  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action)
    VALUES (NEW.organization_id, 'file', NEW.id, _user_id, 'deleted');
    RETURN NEW;
  END IF;

  IF OLD.deleted_at IS DISTINCT FROM NEW.deleted_at THEN
    RETURN NEW;
  END IF;

  IF OLD.file_name IS DISTINCT FROM NEW.file_name THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.organization_id, 'file', NEW.id, _user_id, 'updated_field',
       'file_name', OLD.file_name, NEW.file_name);
  END IF;

  IF OLD.folder_id IS DISTINCT FROM NEW.folder_id THEN
    INSERT INTO public.wiki_activities
      (organization_id, target_type, target_id, user_id, action, field_name, old_value, new_value)
    VALUES
      (NEW.organization_id, 'file', NEW.id, _user_id, 'updated_field',
       'folder_id',
       public.wiki_folder_label(OLD.folder_id),
       public.wiki_folder_label(NEW.folder_id));
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_wiki_file_changes
  AFTER UPDATE ON public.wiki_files
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_log_wiki_file_changes();

-- 6. Extend unified admin activity log RPC with wiki branch

CREATE OR REPLACE FUNCTION public.get_admin_activity_log(
  _type   text DEFAULT 'all',
  _limit  int  DEFAULT 25,
  _offset int  DEFAULT 0
)
RETURNS TABLE (
  id                uuid,
  source_type       text,
  source_id         uuid,
  source_label      text,
  source_project_id uuid,
  user_id           uuid,
  user_name         text,
  user_avatar       text,
  action            public.activity_action,
  field_name        text,
  old_value         text,
  new_value         text,
  created_at        timestamptz
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

    UNION ALL

    SELECT
      wa.id,
      ('wiki_' || wa.target_type::text)::text                     AS source_type,
      wa.target_id                                                AS source_id,
      COALESCE(wp.title, wf.name, wfl.file_name, '(deleted)')     AS source_label,
      NULL::uuid                                                  AS source_project_id,
      wa.user_id,
      u.full_name                                                 AS user_name,
      u.avatar_url                                                AS user_avatar,
      wa.action,
      wa.field_name::text,
      wa.old_value,
      wa.new_value,
      wa.created_at
    FROM public.wiki_activities wa
    JOIN public.users u              ON u.id = wa.user_id
    LEFT JOIN public.wiki_pages   wp  ON wa.target_type = 'page'   AND wp.id  = wa.target_id
    LEFT JOIN public.wiki_folders wf  ON wa.target_type = 'folder' AND wf.id  = wa.target_id
    LEFT JOIN public.wiki_files   wfl ON wa.target_type = 'file'   AND wfl.id = wa.target_id
    WHERE (_type = 'all' OR _type = 'wiki')
  ) combined
  ORDER BY created_at DESC
  LIMIT _limit
  OFFSET _offset;
END;
$$;

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
  _c     bigint;
BEGIN
  IF _type = 'all' OR _type = 'task' THEN
    SELECT count(*) INTO _c FROM public.task_activities;
    _count := _count + _c;
  END IF;
  IF _type = 'all' OR _type = 'ticket' THEN
    SELECT count(*) INTO _c FROM public.ticket_activities;
    _count := _count + _c;
  END IF;
  IF _type = 'all' OR _type = 'wiki' THEN
    SELECT count(*) INTO _c FROM public.wiki_activities;
    _count := _count + _c;
  END IF;
  RETURN _count;
END;
$$;
